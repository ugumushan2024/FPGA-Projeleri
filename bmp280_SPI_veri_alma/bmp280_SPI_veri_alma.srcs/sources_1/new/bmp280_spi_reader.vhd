library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bmp280_spi_reader is
    Generic (
        CLK_FREQ    : integer := 100_000_000; -- Nexys A7 100 MHz Sistem Saati
        SPI_FREQ    : integer := 1_000_000;   -- 1 MHz SPI SCLK Frekansi
        Startup_Dly : integer := 200_000;     -- 2 ms Baslangic Gecikmesi (Simulasyonda kucultulebilir)
        Meas_Period : integer := 10_000_000   -- 100 ms Okuma Periyodu (10 Hz)
    );
    Port (
        clk          : in   std_logic;                     -- 100 MHz Saat
        rst_n        : in   std_logic;                     -- Aktif-Dusuk Reset (Nexys A7 CPU_RESETN)
        
        -- SPI Fiziksel Arayuzu (PMOD)
        spi_sclk     : out std_logic;
        spi_mosi     : out std_logic;
        spi_miso     : in  std_logic;
        spi_cs_n     : out std_logic;
        
        -- Kullanici / Veri Cikis Arayuzu
        temp_raw_out : out std_logic_vector(19 downto 0); -- 20-bit Ham Sicaklik Verisi
        data_valid   : out std_logic                      -- Yeni veri hazir darbesi (1 clk)
    );
end bmp280_spi_reader;

architecture Behavioral of bmp280_spi_reader is

    -- =========================================================================
    -- 1. BMP280 SABITLERI (DATASHEET)
    -- =========================================================================
    -- Yazma isleminde MSB='0' (0xF4 AND 0x7F = 0x74)
    constant CMD_WRITE_CTRL_MEAS : std_logic_vector(7 downto 0) := x"74"; 
    -- osrs_t = 001 (x1 temp), osrs_p = 000 (basinc kapali), mode = 11 (Normal Mode) -> 0010_0011 = 0x23
    -- (Basinci da x1 acmak istersen 0x27 yapabilirsin)
    constant VAL_CTRL_MEAS       : std_logic_vector(7 downto 0) := x"27"; 
    -- Okuma isleminde MSB='1' (0xFA OR 0x80 = 0xFA)
    constant CMD_READ_TEMP_MSB   : std_logic_vector(7 downto 0) := x"FA";
    constant DUMMY_BYTE          : std_logic_vector(7 downto 0) := x"00";

    -- =========================================================================
    -- 2. FSM DURUM TANIMLARI
    -- =========================================================================
    type state_type is (
        ST_POWER_UP,       -- Sensörün uyanmasini bekle (2 ms)
        ST_INIT_CS_LOW,    -- Konfigurasyon icin CS_N = '0' yap
        ST_INIT_SEND_ADDR, -- 0x74 adresini gonder
        ST_INIT_SEND_DATA, -- 0x27 verisini gonder
        ST_INIT_CS_HIGH,   -- Konfigurasyon bitti, CS_N = '1' yap
        ST_WAIT_PERIOD,    -- Olcum periyodunu bekle (100 ms)
        ST_READ_CS_LOW,    -- Okuma icin CS_N = '0' yap
        ST_READ_SEND_ADDR, -- 0xFA okuma adresini gonder
        ST_READ_MSB,       -- 1. Bayti oku (temp_msb [19:12])
        ST_READ_LSB,       -- 2. Bayti oku (temp_lsb [11:4])
        ST_READ_XLSB,      -- 3. Bayti oku (temp_xlsb [3:0])
        ST_LATCH_DATA      -- CS_N = '1' yap ve 20-bit veriyi cikisa aktar
    );
    signal state : state_type := ST_POWER_UP;

    -- =========================================================================
    -- 3. SAAT BOLUCU VE SPI ZAMANLAMA SINYALLERI
    -- =========================================================================
    constant HALF_PERIOD : integer := CLK_FREQ / (2 * SPI_FREQ); -- 100MHz / 2MHz = 50 clk
    signal clk_cnt       : integer range 0 to HALF_PERIOD - 1 := 0;
    signal sclk_reg      : std_logic := '0';
    signal sclk_en       : std_logic := '0'; -- Sadece veri transferi sirasinda '1' olur
    signal sclk_rise     : std_logic := '0'; -- Ornekleme (Sample) ani (CPHA=0)
    signal sclk_fall     : std_logic := '0'; -- Kaydirma (Shift) ani (CPHA=0)

    -- =========================================================================
    -- 4. KAYDIRMA YAZMACLARI (SHIFT REGISTERS) VE SAYACLAR
    -- =========================================================================
    signal tx_shift_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_shift_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_cnt       : integer range 0 to 7 := 0;
    signal timer_cnt     : integer range 0 to Meas_Period := 0;

    -- =========================================================================
    -- 5. SICAKLIK VERI YAZMACLARI VE SENKRONIZASYON
    -- =========================================================================
    signal temp_msb_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_lsb_reg  : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_xlsb_reg : std_logic_vector(7 downto 0) := (others => '0');
    
    -- MISO Cift Flip-Flop Senkronizasyonu
    signal miso_sync     : std_logic_vector(1 downto 0) := "00";

begin

    -- Cikis Atamalari
    spi_sclk <= sclk_reg;
    spi_mosi <= tx_shift_reg(7); -- Her zaman MSB (Bit 7) hatta surulur

    -- =========================================================================
    -- PROCESS 1: MISO Giris Senkronizasyonu (Metastability Onlemi)
    -- =========================================================================
    process(clk)
    begin
        if rising_edge(clk) then
            miso_sync <= miso_sync(0) & spi_miso;
        end if;
    end process;

    -- =========================================================================
    -- PROCESS 2: SPI Saat (SCLK) ve Kenar (Edge) Uretici
    -- Sadece sclk_en = '1' iken SCLK uretir, diger zamanlarda SCLK = '0' (CPOL=0)
    -- =========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            clk_cnt   <= 0;
            sclk_reg  <= '0';
            sclk_rise <= '0';
            sclk_fall <= '0';
        elsif rising_edge(clk) then
            -- Varsayilan olarak darbe (pulse) sinyalleri '0'
            sclk_rise <= '0';
            sclk_fall <= '0';

            if sclk_en = '1' then
                if clk_cnt = HALF_PERIOD - 1 then
                    clk_cnt  <= 0;
                    sclk_reg <= not sclk_reg;
                    
                    if sclk_reg = '0' then
                        sclk_rise <= '1'; -- 0'dan 1'e gecis (Rising Edge)
                    else
                        sclk_fall <= '1'; -- 1'den 0'a gecis (Falling Edge)
                    end if;
                else
                    clk_cnt <= clk_cnt + 1;
                end if;
            else
                clk_cnt  <= 0;
                sclk_reg <= '0'; -- CPOL = 0
            end if;
        end if;
    end process;

    -- =========================================================================
    -- PROCESS 3: Ana Kontrol FSM ve SPI Veri Yolu
    -- =========================================================================
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state         <= ST_POWER_UP;
            spi_cs_n      <= '1';
            sclk_en       <= '0';
            timer_cnt     <= 0;
            bit_cnt       <= 0;
            tx_shift_reg  <= (others => '0');
            rx_shift_reg  <= (others => '0');
            temp_msb_reg  <= (others => '0');
            temp_lsb_reg  <= (others => '0');
            temp_xlsb_reg <= (others => '0');
            temp_raw_out  <= (others => '0');
            data_valid    <= '0';
            
        elsif rising_edge(clk) then
            data_valid <= '0'; -- Varsayilan olarak tek clock darbesi

            case state is

                -- -------------------------------------------------------------
                -- 1. BASLANGIC GECIKMESI (2 ms)
                -- -------------------------------------------------------------
                when ST_POWER_UP =>
                    spi_cs_n <= '1';
                    sclk_en  <= '0';
                    if timer_cnt = Startup_Dly - 1 then
                        timer_cnt <= 0;
                        state     <= ST_INIT_CS_LOW;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

                -- -------------------------------------------------------------
                -- 2. KONFIGURASYON: 0xF4 (ctrl_meas) YAZMACINA 0x27 YAZMA
                -- -------------------------------------------------------------
                when ST_INIT_CS_LOW =>
                    spi_cs_n     <= '0';                  -- Slave secildi
                    tx_shift_reg <= CMD_WRITE_CTRL_MEAS;  -- 0x74 yuklendi (MSB aninda MOSI'de)
                    bit_cnt      <= 7;
                    sclk_en      <= '1';                  -- SCLK baslat
                    state        <= ST_INIT_SEND_ADDR;

                when ST_INIT_SEND_ADDR =>
                    if sclk_rise = '1' then
                        rx_shift_reg <= rx_shift_reg(6 downto 0) & miso_sync(1);
                    elsif sclk_fall = '1' then
                        if bit_cnt = 0 then
                            tx_shift_reg <= VAL_CTRL_MEAS; -- 2. Bayt (0x27) yuklendi
                            bit_cnt      <= 7;
                            state        <= ST_INIT_SEND_DATA;
                        else
                            tx_shift_reg <= tx_shift_reg(6 downto 0) & '0';
                            bit_cnt      <= bit_cnt - 1;
                        end if;
                    end if;

                when ST_INIT_SEND_DATA =>
                    if sclk_rise = '1' then
                        rx_shift_reg <= rx_shift_reg(6 downto 0) & miso_sync(1);
                    elsif sclk_fall = '1' then
                        if bit_cnt = 0 then
                            sclk_en <= '0';               -- Transfer bitti, SCLK durdur
                            state   <= ST_INIT_CS_HIGH;
                        else
                            tx_shift_reg <= tx_shift_reg(6 downto 0) & '0';
                            bit_cnt      <= bit_cnt - 1;
                        end if;
                    end if;

                when ST_INIT_CS_HIGH =>
                    spi_cs_n  <= '1';                     -- Konfigurasyon islemi kapandi
                    timer_cnt <= 0;
                    state     <= ST_WAIT_PERIOD;

                -- -------------------------------------------------------------
                -- 3. OLCUM PERIYODU BEKLEME (100 ms)
                -- -------------------------------------------------------------
                when ST_WAIT_PERIOD =>
                    if timer_cnt = Meas_Period - 1 then
                        timer_cnt <= 0;
                        state     <= ST_READ_CS_LOW;
                    else
                        timer_cnt <= timer_cnt + 1;
                    end if;

                -- -------------------------------------------------------------
                -- 4. SICAKLIK OKUMA (BURST READ: 0xFA, 0xFB, 0xFC)
                -- -------------------------------------------------------------
                when ST_READ_CS_LOW =>
                    spi_cs_n     <= '0';
                    tx_shift_reg <= CMD_READ_TEMP_MSB;    -- 0xFA okuma adresi yuklendi
                    bit_cnt      <= 7;
                    sclk_en      <= '1';
                    state        <= ST_READ_SEND_ADDR;

                when ST_READ_SEND_ADDR =>
                    if sclk_rise = '1' then
                        rx_shift_reg <= rx_shift_reg(6 downto 0) & miso_sync(1);
                    elsif sclk_fall = '1' then
                        if bit_cnt = 0 then
                            tx_shift_reg <= DUMMY_BYTE;   -- Okuma yaparken MOSI = 0x00
                            bit_cnt      <= 7;
                            state        <= ST_READ_MSB;
                        else
                            tx_shift_reg <= tx_shift_reg(6 downto 0) & '0';
                            bit_cnt      <= bit_cnt - 1;
                        end if;
                    end if;

                when ST_READ_MSB =>
                    if sclk_rise = '1' then
                        rx_shift_reg <= rx_shift_reg(6 downto 0) & miso_sync(1);
                    elsif sclk_fall = '1' then
                        if bit_cnt = 0 then
                            temp_msb_reg <= rx_shift_reg; -- 0xFA verisi kaydedildi
                            tx_shift_reg <= DUMMY_BYTE;
                            bit_cnt      <= 7;
                            state        <= ST_READ_LSB;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when ST_READ_LSB =>
                    if sclk_rise = '1' then
                        rx_shift_reg <= rx_shift_reg(6 downto 0) & miso_sync(1);
                    elsif sclk_fall = '1' then
                        if bit_cnt = 0 then
                            temp_lsb_reg <= rx_shift_reg; -- 0xFB verisi kaydedildi
                            tx_shift_reg <= DUMMY_BYTE;
                            bit_cnt      <= 7;
                            state        <= ST_READ_XLSB;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when ST_READ_XLSB =>
                    if sclk_rise = '1' then
                        rx_shift_reg <= rx_shift_reg(6 downto 0) & miso_sync(1);
                    elsif sclk_fall = '1' then
                        if bit_cnt = 0 then
                            temp_xlsb_reg <= rx_shift_reg; -- 0xFC verisi kaydedildi
                            sclk_en       <= '0';          -- 3 bayt okundu, SCLK durdur
                            state         <= ST_LATCH_DATA;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                -- -------------------------------------------------------------
                -- 5. VERIYI BIRLESTIRME VE CIKISA AKTARMA
                -- -------------------------------------------------------------
                when ST_LATCH_DATA =>
                    spi_cs_n     <= '1'; -- Okuma paketi tamamlandi
                    -- 20-bit birlestirme: MSB(8-bit) & LSB(8-bit) & XLSB(ust 4-bit)
                    temp_raw_out <= temp_msb_reg & temp_lsb_reg & temp_xlsb_reg(7 downto 4);
                    data_valid   <= '1'; -- Yeni veri hazir sinyali
                    timer_cnt    <= 0;
                    state        <= ST_WAIT_PERIOD;

                when others =>
                    state <= ST_POWER_UP;

            end case;
        end if;
    end process;

end Behavioral;