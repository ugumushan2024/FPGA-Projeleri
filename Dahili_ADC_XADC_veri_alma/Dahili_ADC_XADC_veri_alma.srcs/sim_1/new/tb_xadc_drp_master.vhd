library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_xadc_drp_master is
-- Testbench entity'si boş bırakılır
end tb_xadc_drp_master;

architecture Behavioral of tb_xadc_drp_master is

    -- Test edilecek modülün (UUT) tanımlanması
    component xadc_drp_master
        Port (
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            eoc_in      : in  STD_LOGIC;
            do_in       : in  STD_LOGIC_VECTOR(15 downto 0);
            drdy_in     : in  STD_LOGIC;
            daddr_out   : out STD_LOGIC_VECTOR(6 downto 0);
            den_out     : out STD_LOGIC;
            dwe_out     : out STD_LOGIC;
            di_out      : out STD_LOGIC_VECTOR(15 downto 0);
            temp_data   : out STD_LOGIC_VECTOR(11 downto 0);
            data_valid  : out STD_LOGIC
        );
    end component;

    -- Giriş Sinyalleri
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '0';
    signal eoc_in  : std_logic := '0';
    signal do_in   : std_logic_vector(15 downto 0) := (others => '0');
    signal drdy_in : std_logic := '0';

    -- Çıkış Sinyalleri
    signal daddr_out  : std_logic_vector(6 downto 0);
    signal den_out    : std_logic;
    signal dwe_out    : std_logic;
    signal di_out     : std_logic_vector(15 downto 0);
    signal temp_data  : std_logic_vector(11 downto 0);
    signal data_valid : std_logic;

    -- Nexys A7 100 MHz saat sinyali periyodu
    constant clk_period : time := 10 ns;

begin

    -- UUT (Unit Under Test) Bağlantısı
    uut: xadc_drp_master PORT MAP (
        clk => clk,
        reset => reset,
        eoc_in => eoc_in,
        do_in => do_in,
        drdy_in => drdy_in,
        daddr_out => daddr_out,
        den_out => den_out,
        dwe_out => dwe_out,
        di_out => di_out,
        temp_data => temp_data,
        data_valid => data_valid
    );

    -- Clock (Saat) Üretimi Süreci
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus (Uyarıcı/Senaryo) Süreci
    stim_proc: process
    begin
        -- 1. SISTEMI SIFIRLA
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        wait for 20 ns;

        -- 2. BİRİNCİ OKUMA SENARYOSU (Sahte XADC Davranışı)
        -- XADC "dönüştürme bitti" (EOC) sinyali gönderiyor
        eoc_in <= '1';
        wait for clk_period;
        eoc_in <= '0';

        -- FSM'in okuma isteği göndermesini (den_out = '1') bekle
        wait until den_out = '1';
        
        -- DRP veriyi getirene kadar birkaç clock bekle (XADC gecikmesi simülasyonu)
        wait for clk_period * 3;
        
        -- Sahte (Mock) Veri Gönderimi
        -- 16-bit Ham Veri: 0x8A53 (Binary: 1000 1010 0101 0011)
        -- Beklenen Kırpılmış 12-bit temp_data: 0x8A5
        do_in <= x"8A53"; 
        drdy_in <= '1'; -- XADC "DRP Verisi Hazır" diyor
        wait for clk_period;
        drdy_in <= '0';

        -- Verinin output register'ına işlenmesi için bekle
        wait for clk_period * 2;

        -- 3. İKİNCİ OKUMA SENARYOSU
        wait for 50 ns;
        eoc_in <= '1';
        wait for clk_period;
        eoc_in <= '0';

        wait until den_out = '1';
        wait for clk_period * 2;

        -- Yeni Sahte Veri: 0x3F20 -> Beklenen Kırpılmış: 0x3F2
        do_in <= x"3F20";
        drdy_in <= '1';
        wait for clk_period;
        drdy_in <= '0';

        wait; -- Simülasyonu bitir ve durdur
    end process;

end Behavioral;