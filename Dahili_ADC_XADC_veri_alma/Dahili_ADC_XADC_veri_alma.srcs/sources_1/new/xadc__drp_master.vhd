library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity xadc_drp_master is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        -- XADC IP'sinden Gelen Durum Sinyali
        eoc_in      : in  STD_LOGIC;  
        
        -- XADC DRP (Dynamic Reconfiguration Port) Arayüzü
        do_in       : in  STD_LOGIC_VECTOR(15 downto 0); 
        drdy_in     : in  STD_LOGIC;                     
        daddr_out   : out STD_LOGIC_VECTOR(6 downto 0);  
        den_out     : out STD_LOGIC;                     
        dwe_out     : out STD_LOGIC;                     
        di_out      : out STD_LOGIC_VECTOR(15 downto 0); 
        
        -- Sistem Arayüzü Çıkışları
        temp_data   : out STD_LOGIC_VECTOR(11 downto 0); 
        data_valid  : out STD_LOGIC                      
    );
end xadc_drp_master;

architecture Behavioral of xadc_drp_master is

    type fsm_state is (S_IDLE, S_READ_REQ, S_WAIT_DRDY, S_LATCH_DATA);
    signal current_state : fsm_state := S_IDLE;

    -- JXADC Pmod portundaki Vaux4 kanalı için XADC register adresi (0x14)
    constant ADDR_VAUX4 : STD_LOGIC_VECTOR(6 downto 0) := "0010100";

begin

    dwe_out   <= '0';
    di_out    <= (others => '0');
    daddr_out <= ADDR_VAUX4; 

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_IDLE;
                den_out       <= '0';
                data_valid    <= '0';
                temp_data     <= (others => '0');
            else
                case current_state is
                    when S_IDLE =>
                        data_valid <= '0';
                        den_out    <= '0';
                        if eoc_in = '1' then
                            current_state <= S_READ_REQ;
                        end if;

                    when S_READ_REQ =>
                        den_out <= '1'; 
                        current_state <= S_WAIT_DRDY;

                    when S_WAIT_DRDY =>
                        den_out <= '0'; 
                        if drdy_in = '1' then
                            current_state <= S_LATCH_DATA;
                        end if;

                    when S_LATCH_DATA =>
                        temp_data  <= do_in(15 downto 4);
                        data_valid <= '1'; 
                        current_state <= S_IDLE;

                    when others =>
                        current_state <= S_IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;