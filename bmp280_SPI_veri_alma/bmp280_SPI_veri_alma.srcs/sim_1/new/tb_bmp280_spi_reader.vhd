library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_bmp280_spi_reader is
-- Testbench'in portlari olmaz
end tb_bmp280_spi_reader;

architecture Behavioral of tb_bmp280_spi_reader is

    -- 1. Test Edilecek Modul (UUT) Tanimi
    component bmp280_spi_reader
        Generic (
            CLK_FREQ    : integer;
            SPI_FREQ    : integer;
            Startup_Dly : integer;
            Meas_Period : integer
        );
        Port (
            clk          : in   std_logic;
            rst_n        : in   std_logic;
            spi_sclk     : out  std_logic;
            spi_mosi     : out  std_logic;
            spi_miso     : in   std_logic;
            spi_cs_n     : out  std_logic;
            temp_raw_out : out  std_logic_vector(19 downto 0);
            data_valid   : out  std_logic
        );
    end component;

    -- 2. Ic Sinyaller
    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';
    signal spi_sclk     : std_logic;
    signal spi_mosi     : std_logic;
    signal spi_miso     : std_logic := '0';
    signal spi_cs_n     : std_logic;
    signal temp_raw_out : std_logic_vector(19 downto 0);
    signal data_valid   : std_logic;

    -- 100 MHz Saat Periyodu (10 ns)
    constant CLK_PERIOD : time := 10 ns;

    -- Sanal BMP280 Slave Bellegi (Ornek Ham Sicaklik: 0x7EA53)
    -- MSB = 0x7E, LSB = 0xA5, XLSB = 0x30 (Son 4 bit 0'dir)
    type byte_array is array (0 to 2) of std_logic_vector(7 downto 0);
    constant FAKE_BMP280_MEM : byte_array := (x"7E", x"A5", x"30");

    -- Sanal Slave Izleme Sinyalleri (Dalga formunda kolay gormek icin)
    signal slave_rx_addr : std_logic_vector(7 downto 0) := (others => '0');
    signal slave_rx_data : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- =========================================================================
    -- UUT (Unit Under Test) Baglantisi
    -- Simulasyon hizi icin SPI_FREQ = 10 MHz, gecikmeler 100 ve 200 clk yapildi
    -- =========================================================================
    uut: bmp280_spi_reader
        generic map (
            CLK_FREQ    => 100_000_000,
            SPI_FREQ    => 10_000_000, -- Simulasyonda hizli gormek icin 10 MHz
            Startup_Dly => 100,        -- 1 us baslangic beklemesi
            Meas_Period => 200         -- 2 us olcum periyodu
        )
        port map (
            clk          => clk,
            rst_n        => rst_n,
            spi_sclk     => spi_sclk,
            spi_mosi     => spi_mosi,
            spi_miso     => spi_miso,
            spi_cs_n     => spi_cs_n,
            temp_raw_out => temp_raw_out,
            data_valid   => data_valid
        );

    -- =========================================================================
    -- 100 MHz Sistem Saati Uretimi
    -- =========================================================================
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- =========================================================================
    -- Sanal BMP280 SPI Slave Modeli (Mod 0: CPOL=0, CPHA=0)
    -- =========================================================================
    bmp280_slave_model : process
        variable rx_byte : std_logic_vector(7 downto 0);
        variable tx_byte : std_logic_vector(7 downto 0);
    begin
        -- Baslangicta Reset birakilana kadar bekle
        rst_n    <= '0';
        spi_miso <= '0';
        wait for 100 ns;
        rst_n    <= '1';

        -- ---------------------------------------------------------------------
        -- 1. PAKET: KONFIGURASYON YAZMA TESTI (Beklenen: 0x74 ve 0x27)
        -- ---------------------------------------------------------------------
        wait until falling_edge(spi_cs_n);
        
        -- 1. Bayt: Adres Alimi (Rising edge'de ornekle)
        for i in 7 downto 0 loop
            wait until rising_edge(spi_sclk);
            rx_byte(i) := spi_mosi;
        end loop;
        slave_rx_addr <= rx_byte;
        
        assert (rx_byte = x"74") 
            report "HATA: Konfigurasyon yazma adresi 0x74 degil!" severity error;

        -- 2. Bayt: Konfigurasyon Verisi Alimi
        for i in 7 downto 0 loop
            wait until rising_edge(spi_sclk);
            rx_byte(i) := spi_mosi;
        end loop;
        slave_rx_data <= rx_byte;

        assert (rx_byte = x"27") 
            report "HATA: Konfigurasyon verisi 0x27 degil!" severity error;

        wait until rising_edge(spi_cs_n);
        report "BASARILI: BMP280 Konfigurasyon paketi (0x74 -> 0x27) dogru alindi." severity note;

        -- ---------------------------------------------------------------------
        -- 2. PAKET: BURST SICAKLIK OKUMA TESTI (0xFA -> 3 Bayt Cikis)
        -- ---------------------------------------------------------------------
        wait until falling_edge(spi_cs_n);

        -- 1. Bayt: Okuma Adresi Alimi (Beklenen: 0xFA)
        for i in 7 downto 0 loop
            wait until rising_edge(spi_sclk);
            rx_byte(i) := spi_mosi;
        end loop;
        slave_rx_addr <= rx_byte;

        assert (rx_byte = x"FA") 
            report "HATA: Sicaklik okuma adresi 0xFA degil!" severity error;

        -- Sirayla 3 Bayt (MSB, LSB, XLSB) MISO hattina surulur
        -- SPI Mod 0'da Slave, SCLK'un dusen kenarinda (falling_edge) MISO'yu degistirir
        for byte_idx in 0 to 2 loop
            tx_byte := FAKE_BMP280_MEM(byte_idx);
            for bit_idx in 7 downto 0 loop
                wait until falling_edge(spi_sclk);
                spi_miso <= tx_byte(bit_idx);
            end loop;
        end loop;

        wait until rising_edge(spi_cs_n);
        spi_miso <= '0';

        -- Cikis Verisi ve data_valid Kontrolu
        wait until rising_edge(data_valid);
        wait for 1 ns; -- Sinyalin oturmasini bekle
        
        assert (temp_raw_out = x"7EA53")
            report "HATA: Cikis verisi 0x7EA53 ile eslesmiyor!" severity error;
            
        report "SIMULASYON TAMAMLANDI: temp_raw_out = 0x7EA53 basariyla okundu!" severity note;

        wait; -- Simulasyonu durdur
    end process;

end Behavioral;