library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_module is
    Port (
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        
        -- JXADC Port Pinleri (LM35'in bağlanacağı Diferansiyel Pinler)
        vauxp4      : in STD_LOGIC;
        vauxn4      : in STD_LOGIC;
        
        -- Sensör verisini görmek için LED'ler
        led         : out STD_LOGIC_VECTOR(11 downto 0)
    );
end top_module;

architecture Structural of top_module is

    -- Modüller arası bağlantıyı sağlayacak iç kablolar (Signals)
    signal eoc_sig   : STD_LOGIC;
    signal do_sig    : STD_LOGIC_VECTOR(15 downto 0);
    signal drdy_sig  : STD_LOGIC;
    signal daddr_sig : STD_LOGIC_VECTOR(6 downto 0);
    signal den_sig   : STD_LOGIC;
    signal dwe_sig   : STD_LOGIC;
    signal di_sig    : STD_LOGIC_VECTOR(15 downto 0);
    
    signal temp_data_sig : STD_LOGIC_VECTOR(11 downto 0);

    -- Vivado'nun ürettiği XADC IP Core'unun prototipi
    component xadc_wiz_0
        port (
            daddr_in        : in  STD_LOGIC_VECTOR(6 downto 0);
            den_in          : in  STD_LOGIC;
            di_in           : in  STD_LOGIC_VECTOR(15 downto 0);
            dwe_in          : in  STD_LOGIC;
            do_out          : out STD_LOGIC_VECTOR(15 downto 0);
            drdy_out        : out STD_LOGIC;
            dclk_in         : in  STD_LOGIC;
            reset_in        : in  STD_LOGIC;
            vauxp4          : in  STD_LOGIC;
            vauxn4          : in  STD_LOGIC;
            channel_out     : out STD_LOGIC_VECTOR(4 downto 0);
            eoc_out         : out STD_LOGIC;
            alarm_out       : out STD_LOGIC;
            eos_out         : out STD_LOGIC;
            busy_out        : out STD_LOGIC
        );
    end component;

    -- Bizim yazdığımız DRP Master Kontrolcü prototipi
    component xadc_drp_master
        port (
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

begin

    -- Sensörden okunan 12-bit veriyi doğrudan LED portuna aktar
    led <= temp_data_sig;

    -- XADC IP Core Çağrısı ve Bağlantıları
    XADC_INST : xadc_wiz_0
        port map (
            daddr_in    => daddr_sig,
            den_in      => den_sig,
            di_in       => di_sig,
            dwe_in      => dwe_sig,
            do_out      => do_sig,
            drdy_out    => drdy_sig,
            dclk_in     => clk,
            reset_in    => reset,
            vauxp4      => vauxp4,
            vauxn4      => vauxn4,
            channel_out => open,  -- Kullanmadığımız portları 'open' bırakıyoruz
            eoc_out     => eoc_sig,
            alarm_out   => open,
            eos_out     => open,
            busy_out    => open
        );

    -- DRP Master Modül Çağrısı ve Bağlantıları
    DRP_MASTER_INST : xadc_drp_master
        port map (
            clk         => clk,
            reset       => reset,
            eoc_in      => eoc_sig,
            do_in       => do_sig,
            drdy_in     => drdy_sig,
            daddr_out   => daddr_sig,
            den_out     => den_sig,
            dwe_out     => dwe_sig,
            di_out      => di_sig,
            temp_data   => temp_data_sig,
            data_valid  => open
        );

end Structural;