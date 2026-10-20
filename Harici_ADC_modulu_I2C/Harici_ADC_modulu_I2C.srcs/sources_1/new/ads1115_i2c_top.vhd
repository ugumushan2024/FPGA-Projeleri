library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ads1115_i2c_top is
    Port (
        clk        : in    std_logic;                      -- 100 MHz Sistem Saati (E3)
        rst_n      : in    std_logic;                      -- Aktif-Düşük Reset (CPU_RESETN - C12)
        i2c_sda    : inout std_logic;                      -- I2C Veri Hattı (Pmod JA Pin 1 - C17)
        i2c_scl    : inout std_logic;                      -- I2C Saat Hattı (Pmod JA Pin 2 - D18)
        adc_led    : out   std_logic_vector(15 downto 0);  -- 16-Bit Ham ADC Çıkışı (LED15..LED0)
        ack_err_led: out   std_logic;                      -- I2C NACK Hata Göstergesi (LED16_R)
        busy_led   : out   std_logic                       -- İletişim Aktif Göstergesi (LED17_G)
    );
end ads1115_i2c_top;

architecture Behavioral of ads1115_i2c_top is

    -- 100 MHz -> 400 kHz (4 Fazlı 100 kHz I2C SCL) için Saat Bölücü Sabiti
    -- 100_000_000 / 400_000 = 250 darbe (0..249)
    constant CLK_DIV_MAX : integer := 249;
    signal clk_cnt       : integer range 0 to CLK_DIV_MAX := 0;
    signal phase_tick    : std_logic := '0';
    signal phase         : unsigned(1 downto 0) := "00"; -- 00: Faz0, 01: Faz1, 10: Faz2, 11: Faz3

    -- Okumalar arası 100 ms bekleme sayacı (400 kHz tick üzerinden: 40_000 tick = 100 ms)
    constant WAIT_100MS  : integer := 20;
    signal delay_cnt     : integer range 0 to 40000 := 0;

    -- Open-Drain (Tri-State) Kontrol Sinyalleri ('0' -> Hattı Sıfıra Çek, '1' -> 'Z' Bırak)
    signal sda_out       : std_logic := '1';
    signal scl_out       : std_logic := '1';
    signal sda_in        : std_logic := '1';

    -- FSM Durum Tanımları
    type state_type is (
        ST_POWER_UP,       -- Başlangıç beklemesi
        ST_START,          -- I2C START koşulu üretimi
        ST_SEND_BYTE,      -- 8-bit veri gönderimi (MSB -> LSB)
        ST_WAIT_ACK,       -- Slave ACK kontrolü
        ST_READ_MSB,       -- Üst 8-bit okuma
        ST_SEND_M_ACK,     -- Master ACK gönderimi (MSB sonrası)
        ST_READ_LSB,       -- Alt 8-bit okuma
        ST_SEND_M_NACK,    -- Master NACK gönderimi (LSB sonrası)
        ST_STOP,           -- I2C STOP koşulu üretimi
        ST_DELAY           -- İki okuma veya aşama arası bekleme
    );
    signal state : state_type := ST_POWER_UP;

    -- İletişim Aşamaları (3 Aşamalı Senaryo)
    -- 0: Config Yazma (0x90 -> 0x01 -> 0x44 -> 0x83)
    -- 1: Pointer Yazma (0x90 -> 0x00)
    -- 2: Sürekli Okuma (0x91 -> Read MSB -> Read LSB)
    signal stage_idx     : integer range 0 to 2 := 0;
    signal byte_idx      : integer range 0 to 3 := 0;
    signal bit_cnt       : integer range 0 to 7 := 7;

    -- Veri Kayıtçıları
    signal tx_byte       : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_msb        : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_lsb        : std_logic_vector(7 downto 0) := (others => '0');
    signal raw_adc_reg   : std_logic_vector(15 downto 0) := (others => '0');
    signal ack_error_reg : std_logic := '0';

    -- ADS1115 Sabitleri (ADDR = GND -> 7-bit Adres: 0x48)
    constant SLAVE_ADDR_W : std_logic_vector(7 downto 0) := x"90"; -- 0x48 << 1 | 0
    constant SLAVE_ADDR_R : std_logic_vector(7 downto 0) := x"91"; -- 0x48 << 1 | 1
    constant REG_CONV     : std_logic_vector(7 downto 0) := x"00"; -- Conversion Register
    constant REG_CONFIG   : std_logic_vector(7 downto 0) := x"01"; -- Config Register
    -- Config = 0x4483 (OS=0, MUX=100 [AIN0-GND], PGA=010 [+-2.048V], MODE=0 [Cont], DR=100 [128SPS], COMP=Disable)
    constant CFG_MSB      : std_logic_vector(7 downto 0) := x"44";
    constant CFG_LSB      : std_logic_vector(7 downto 0) := x"83";

begin

    -- =========================================================================
    -- 1. OPEN-DRAIN (TRI-STATE) TAMPON ATAMALARI
    -- =========================================================================
    i2c_sda <= '0' when sda_out = '0' else 'Z';
    i2c_scl <= '0' when scl_out = '0' else 'Z';

    -- Hattaki lojik seviyeyi okuma (Simülasyonda 'H' durumunu '1' olarak algılamak için to_X01 kullanılır)
    sda_in  <= to_X01(i2c_sda);

    -- Çıkış LED Atamaları
    adc_led     <= raw_adc_reg;
    ack_err_led <= ack_error_reg;
    busy_led    <= '0' when (state = ST_DELAY or state = ST_POWER_UP) else '1';

    -- =========================================================================
    -- 2. SAAT BÖLÜCÜ VE 4-FAZ ÜRETİCİSİ (100 MHz -> 400 kHz Tick)
    -- =========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            clk_cnt    <= 0;
            phase_tick <= '0';
            phase      <= "00";
        elsif rising_edge(clk) then
            if clk_cnt = CLK_DIV_MAX then
                clk_cnt    <= 0;
                phase_tick <= '1';
                phase      <= phase + 1;
            else
                clk_cnt    <= clk_cnt + 1;
                phase_tick <= '0';
            end if;
        end if;
    end process;

    -- =========================================================================
    -- 3. I2C MASTER DURUM MAKİNESİ (FSM)
    -- =========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state         <= ST_POWER_UP;
            stage_idx     <= 0;
            byte_idx      <= 0;
            bit_cnt       <= 7;
            sda_out       <= '1';
            scl_out       <= '1';
            delay_cnt     <= 0;
            tx_byte       <= (others => '0');
            rx_msb        <= (others => '0');
            rx_lsb        <= (others => '0');
            raw_adc_reg   <= (others => '0');
            ack_error_reg <= '0';

        elsif rising_edge(clk) then
            if phase_tick = '1' then
                case state is

                    -- ---------------------------------------------------------
                    -- Başlangıçta ADC'nin enerjilenmesi için kısa bekleme
                    -- ---------------------------------------------------------
                    when ST_POWER_UP =>
                        sda_out <= '1';
                        scl_out <= '1';
                        if delay_cnt = 10 then
                            if phase = "11" then
                                delay_cnt <= 0;
                                state     <= ST_START;
                            end if;
                        else
                            delay_cnt <= delay_cnt + 1;
                        end if;

                    -- ---------------------------------------------------------
                    -- START Koşulu: SCL='1' iken SDA '1' -> '0' geçişi yapar
                    -- ---------------------------------------------------------
                    when ST_START =>
                        case phase is
                            when "00" =>
                                sda_out <= '1';
                                scl_out <= '1';
                            when "01" =>
                                sda_out <= '0'; -- START: SCL yüksekken SDA düşer
                                scl_out <= '1';
                            when "10" =>
                                sda_out <= '0';
                                scl_out <= '0'; -- SCL düşürülür, veri basmaya hazırlık
                            when "11" =>
                                bit_cnt <= 7;
                                -- Hangi aşamada olduğumuza göre ilk gönderilecek adres byte'ını yükle
                                if stage_idx = 0 or stage_idx = 1 then
                                    tx_byte <= SLAVE_ADDR_W; -- 0x90
                                else
                                    tx_byte <= SLAVE_ADDR_R; -- 0x91
                                end if;
                                state <= ST_SEND_BYTE;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- 8-Bit Veri Gönderimi (MSB'den LSB'ye)
                    -- ---------------------------------------------------------
                    when ST_SEND_BYTE =>
                        case phase is
                            when "00" =>
                                scl_out <= '0';
                                sda_out <= tx_byte(bit_cnt); -- Veriyi SDA'ya yerleştir
                            when "01" =>
                                scl_out <= '1';              -- SCL yükselir
                            when "10" =>
                                scl_out <= '1';              -- Veri kararlı tutulur
                            when "11" =>
                                scl_out <= '0';              -- SCL düşer
                                if bit_cnt = 0 then
                                    state <= ST_WAIT_ACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                end if;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- Slave ACK Kontrolü (9. Saat Darbesi)
                    -- ---------------------------------------------------------
                    when ST_WAIT_ACK =>
                        case phase is
                            when "00" =>
                                scl_out <= '0';
                                sda_out <= '1'; -- SDA hattını serbest bırak ('Z'), Slave çekecek
                            when "01" =>
                                scl_out <= '1';
                            when "10" =>
                                scl_out <= '1';
                                if sda_in /= '0' then
                                    ack_error_reg <= '1'; -- Slave ACK vermedi!
                                else
                                    ack_error_reg <= '0';
                                end if;
                            when "11" =>
                                scl_out <= '0';
                                bit_cnt <= 7;

                                -- AŞAMA 0: Config Yazma (4 Byte: 0x90 -> 0x01 -> 0x44 -> 0x83)
                                if stage_idx = 0 then
                                    if byte_idx = 0 then
                                        byte_idx <= 1;
                                        tx_byte  <= REG_CONFIG;
                                        state    <= ST_SEND_BYTE;
                                    elsif byte_idx = 1 then
                                        byte_idx <= 2;
                                        tx_byte  <= CFG_MSB;
                                        state    <= ST_SEND_BYTE;
                                    elsif byte_idx = 2 then
                                        byte_idx <= 3;
                                        tx_byte  <= CFG_LSB;
                                        state    <= ST_SEND_BYTE;
                                    else
                                        byte_idx <= 0;
                                        state    <= ST_STOP;
                                    end if;

                                -- AŞAMA 1: Conversion Pointer Yazma (2 Byte: 0x90 -> 0x00)
                                elsif stage_idx = 1 then
                                    if byte_idx = 0 then
                                        byte_idx <= 1;
                                        tx_byte  <= REG_CONV;
                                        state    <= ST_SEND_BYTE;
                                    else
                                        byte_idx <= 0;
                                        state    <= ST_STOP;
                                    end if;

                                -- AŞAMA 2: Okuma Modu (0x91 gönderildi, şimdi MSB okunacak)
                                else
                                    state <= ST_READ_MSB;
                                end if;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- Üst Byte (MSB) Okuma (D15..D8)
                    -- ---------------------------------------------------------
                    when ST_READ_MSB =>
                        case phase is
                            when "00" =>
                                scl_out <= '0';
                                sda_out <= '1'; -- Hat serbest ('Z')
                            when "01" =>
                                scl_out <= '1';
                            when "10" =>
                                scl_out <= '1';
                                rx_msb(bit_cnt) <= sda_in; -- SCL yüksekken hattı örnekle
                            when "11" =>
                                scl_out <= '0';
                                if bit_cnt = 0 then
                                    state <= ST_SEND_M_ACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                end if;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- Master ACK Gönderimi (İkinci byte'ı istemek için SDA='0')
                    -- ---------------------------------------------------------
                    when ST_SEND_M_ACK =>
                        case phase is
                            when "00" =>
                                scl_out <= '0';
                                sda_out <= '0'; -- Master ACK basar
                            when "01" =>
                                scl_out <= '1';
                            when "10" =>
                                scl_out <= '1';
                            when "11" =>
                                scl_out <= '0';
                                sda_out <= '1'; -- Hattı tekrar serbest bırak
                                bit_cnt <= 7;
                                state   <= ST_READ_LSB;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- Alt Byte (LSB) Okuma (D7..D0)
                    -- ---------------------------------------------------------
                    when ST_READ_LSB =>
                        case phase is
                            when "00" =>
                                scl_out <= '0';
                                sda_out <= '1'; -- Hat serbest ('Z')
                            when "01" =>
                                scl_out <= '1';
                            when "10" =>
                                scl_out <= '1';
                                rx_lsb(bit_cnt) <= sda_in; -- SCL yüksekken hattı örnekle
                            when "11" =>
                                scl_out <= '0';
                                if bit_cnt = 0 then
                                    raw_adc_reg <= rx_msb & rx_lsb; -- 16-bit veriyi güncelle
                                    state       <= ST_SEND_M_NACK;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                end if;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- Master NACK Gönderimi (Okumayı bitirmek için SDA='1')
                    -- ---------------------------------------------------------
                    when ST_SEND_M_NACK =>
                        case phase is
                            when "00" =>
                                scl_out <= '0';
                                sda_out <= '1'; -- Master NACK ('Z')
                            when "01" =>
                                scl_out <= '1';
                            when "10" =>
                                scl_out <= '1';
                            when "11" =>
                                scl_out <= '0';
                                state   <= ST_STOP;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- STOP Koşulu: SCL='1' iken SDA '0' -> '1' ('Z') geçişi yapar
                    -- ---------------------------------------------------------
                    when ST_STOP =>
                        case phase is
                            when "00" =>
                                scl_out <= '0';
                                sda_out <= '0'; -- STOP öncesi SDA sıfıra çekilir
                            when "01" =>
                                scl_out <= '1'; -- Önce SCL yükselir
                                sda_out <= '0';
                            when "10" =>
                                scl_out <= '1';
                                sda_out <= '1'; -- STOP: SCL yüksekken SDA yükselir ('Z')
                            when "11" =>
                                delay_cnt <= 0;
                                state     <= ST_DELAY;
                            when others => null;
                        end case;

                    -- ---------------------------------------------------------
                    -- Aşamalar Arası Geçiş ve Periyodik Okuma Beklemesi
                    -- ---------------------------------------------------------
                    when ST_DELAY =>
                        sda_out <= '1';
                        scl_out <= '1';
                        if stage_idx = 0 then
                            -- Config yazıldı, kısa bir süre bekle ve Pointer aşamasına geç
                            if delay_cnt = 10 then
                                if phase = "11" then
                                    delay_cnt <= 0;
                                    stage_idx <= 1;
                                    state     <= ST_START;
                                end if;
                            else
                                delay_cnt <= delay_cnt + 1;
                            end if;
                        elsif stage_idx = 1 then
                            -- Simülasyon için 20 tick bekle (Gerçek donanımda 4000 yapın)
                            if delay_cnt = 20 then
                                if phase = "11" then
                                    delay_cnt <= 0;
                                    stage_idx <= 2;
                                    state     <= ST_START;
                                end if;
                            else
                                delay_cnt <= delay_cnt + 1;
                            end if;
                        else
                            -- Sürekli Okuma Modu
                            if delay_cnt = WAIT_100MS then
                                if phase = "11" then
                                    delay_cnt <= 0;
                                    state     <= ST_START;
                                end if;
                            else
                                delay_cnt <= delay_cnt + 1;
                            end if;
                        end if;

                    when others =>
                        state <= ST_POWER_UP;

                end case;
            end if;
        end if;
    end process;

end Behavioral;