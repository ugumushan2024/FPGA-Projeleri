library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ads1115_i2c is
-- Testbench'in portu olmaz
end tb_ads1115_i2c;

architecture Behavioral of tb_ads1115_i2c is

    -- =========================================================================
    -- 1. TEST EDİLECEK BİRİM (UUT) BİLEŞEN TANIMI
    -- =========================================================================
    component ads1115_i2c_top
        Port (
            clk         : in    std_logic;
            rst_n       : in    std_logic;
            i2c_sda     : inout std_logic;
            i2c_scl     : inout std_logic;
            adc_led     : out   std_logic_vector(15 downto 0);
            ack_err_led : out   std_logic;
            busy_led    : out   std_logic
        );
    end component;

    -- Sistem Sinyalleri
    signal clk         : std_logic := '0';
    signal rst_n       : std_logic := '0';
    signal i2c_sda     : std_logic := 'H';
    signal i2c_scl     : std_logic := 'H';
    signal adc_led     : std_logic_vector(15 downto 0);
    signal ack_err_led : std_logic;
    signal busy_led    : std_logic;

    -- 100 MHz Saat Periyodu (10 ns)
    constant CLK_PERIOD : time := 10 ns;

    -- =========================================================================
    -- 2. SANAL ADS1115 SLAVE MODELİ SİNYALLERİ (Dalga Formunda İzlemek İçin)
    -- =========================================================================
    signal sda_clean          : std_logic;
    signal scl_clean          : std_logic;
    signal slave_sda_out      : std_logic := 'Z';
    
    -- Sanal Sensör Kayıtçıları (Gözlemlemek için Waveform'a ekle!)
    signal tb_rx_shift_reg    : std_logic_vector(7 downto 0)  := (others => '0');
    signal tb_ads_config_reg  : std_logic_vector(15 downto 0) := x"8583"; -- ADS1115 Varsayılan Reset Değeri
    signal tb_ads_pointer_reg : std_logic_vector(7 downto 0)  := x"00";
    
    -- 25.0 Derece = 250 mV -> 250mV / 0.0625mV = 4000 (Hex: 0x0FA0)
    signal tb_simulated_temp  : std_logic_vector(15 downto 0) := x"0FA0"; 

begin

    -- =========================================================================
    -- 3. UUT BAĞLANTISI VE PULL-UP DİRENÇ MODELLEMESİ
    -- =========================================================================
    uut: ads1115_i2c_top
        port map (
            clk         => clk,
            rst_n       => rst_n,
            i2c_sda     => i2c_sda,
            i2c_scl     => i2c_scl,
            adc_led     => adc_led,
            ack_err_led => ack_err_led,
            busy_led    => busy_led
        );

    -- Harici 4.7k Pull-Up Dirençlerinin Simülasyon Karşılığı ('H' = Weak High)
    i2c_sda <= 'H';
    i2c_scl <= 'H';

    -- Sanal Slave'in Open-Drain Sürücüsü
    i2c_sda <= '0' when slave_sda_out = '0' else 'Z';

    -- 'H' seviyelerini lojik '1' olarak okumak için temizlenmiş sinyaller
    sda_clean <= to_X01(i2c_sda);
    scl_clean <= to_X01(i2c_scl);

    -- =========================================================================
    -- 4. 100 MHz SAAT ÜRETİCİSİ VE RESET SÜRECİ
    -- =========================================================================
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    stim_proc: process
    begin
        -- Başlangıçta 200 ns Reset uygula
        rst_n <= '0';
        wait for 200 ns;
        rst_n <= '1';

        -- Simülasyon boyunca bekle (Aşama 0, Aşama 1 ve Okuma döngüleri gerçekleşecek)
        wait;
    end process;

    -- =========================================================================
    -- 5. SANAL ADS1115 I2C SLAVE DAVRANIŞSAL MODELİ (BFM)
    -- =========================================================================
    ads1115_virtual_slave : process
        variable rx_byte   : std_logic_vector(7 downto 0);
        variable tx_word   : std_logic_vector(15 downto 0);
        variable is_read   : boolean := false;
        variable byte_cnt  : integer := 0;
    begin
        slave_sda_out <= 'Z';

        -- 1. START Koşulunu Bekle (SCL = '1' iken SDA düşen kenarı)
        wait until falling_edge(sda_clean) and scl_clean = '1';
        byte_cnt := 0;

        -- 2. İlk Byte'ı Oku (Slave Adresi + R/W Biti: 0x90 veya 0x91)
        for i in 7 downto 0 loop
            wait until rising_edge(scl_clean);
            rx_byte(i) := sda_clean;
        end loop;
        tb_rx_shift_reg <= rx_byte;

        -- 9. Saat Darbesi İçin SCL'nin Düşmesini Bekle
        wait until falling_edge(scl_clean);

        -- Adres Doğrulaması (0x48 = "1001000")
        if rx_byte(7 downto 1) = "1001000" then
            is_read := (rx_byte(0) = '1');
            
            -- Slave ACK Basar ('0')
            slave_sda_out <= '0';
            wait until falling_edge(scl_clean);
            slave_sda_out <= 'Z';

            if not is_read then
                -- =============================================================
                -- YAZMA MODU (0x90): Pointer ve Config Byte'larını Al
                -- =============================================================
                write_loop : loop
                    -- 8 bitin tamamını veya araya girebilecek STOP koşulunu izle
                    for i in 7 downto 0 loop
                        -- SCL yükselene kadar veya STOP koşulu (SCL='1' iken SDA yükselmesi) olana kadar bekle
                        wait until rising_edge(scl_clean) or ( rising_edge(sda_clean) and scl_clean = '1' );
                        
                        if scl_clean = '1' and sda_clean'event and sda_clean = '1' then
                            -- STOP koşulu algılandı, yazma işlemi bitti!
                            exit write_loop;
                        else
                            rx_byte(i) := sda_clean;
                        end if;
                    end loop;

                    tb_rx_shift_reg <= rx_byte;
                    byte_cnt := byte_cnt + 1;

                    -- Gelen Byte'ı İlgili Sanal ADS1115 Kayıtçısına Kaydet
                    if byte_cnt = 1 then
                        tb_ads_pointer_reg <= rx_byte;
                    elsif byte_cnt = 2 and tb_ads_pointer_reg = x"01" then
                        tb_ads_config_reg(15 downto 8) <= rx_byte; -- Config MSB (0x44)
                    elsif byte_cnt = 3 and tb_ads_pointer_reg = x"01" then
                        tb_ads_config_reg(7 downto 0)  <= rx_byte; -- Config LSB (0x83)
                    end if;

                    -- 9. Saat darbesinde Slave ACK ('0') gönder
                    wait until falling_edge(scl_clean);
                    slave_sda_out <= '0';
                    wait until falling_edge(scl_clean);
                    slave_sda_out <= 'Z';
                end loop write_loop;

            else
                -- =============================================================
                -- OKUMA MODU (0x91): 16-Bit Sıcaklık Verisini (MSB + LSB) Gönder
                -- =============================================================
                tx_word := tb_simulated_temp;

                -- 1. Üst Byte (MSB: D15..D8) Gönderimi
                for i in 7 downto 0 loop
                    slave_sda_out <= tx_word(8 + i);
                    wait until falling_edge(scl_clean);
                end loop;
                slave_sda_out <= 'Z'; -- Master ACK için hattı serbest bırak

                -- Master ACK Kontrolü (Master SDA'yı '0' çekmeli)
                wait until rising_edge(scl_clean);
                if sda_clean = '0' then
                    wait until falling_edge(scl_clean);

                    -- 2. Alt Byte (LSB: D7..D0) Gönderimi
                    for i in 7 downto 0 loop
                        slave_sda_out <= tx_word(i);
                        wait until falling_edge(scl_clean);
                    end loop;
                    slave_sda_out <= 'Z'; -- Master NACK için hattı serbest bırak

                    -- Master NACK Darbesinin Bitmesini Bekle
                    wait until falling_edge(scl_clean);

                    -- Bir sonraki okumada grafikte farkı görmek için sıcaklığı +1°C (160 LSB = 0x00A0) artır!
                    tb_simulated_temp <= std_logic_vector(unsigned(tb_simulated_temp) + 160);
                end if;
            end if;
        end if;
    end process;

end Behavioral;