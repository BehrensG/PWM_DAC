library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_dac_core_tb is
end entity pwm_dac_core_tb;

architecture pmw_dac_core_tb_arch of pwm_dac_core_tb is

constant DATA_SIZE : natural := 32;
constant ADDR_SIZE : natural := 4;

    component pwm_dac_core
        generic(
            DATA_SIZE : natural := DATA_SIZE;
            ADDR_SIZE : natural := ADDR_SIZE
        );
        port(
            pwm_a        : out std_logic;
            pwm_b        : out std_logic;
            pwm_clk      : out std_logic;
            axi4l_clk    : in  std_logic;
            axi4l_rst_n  : in  std_logic;
            axi4l_wdata  : in  std_logic_vector(DATA_SIZE - 1 downto 0);
            axi4l_awaddr : in  std_logic_vector(ADDR_SIZE - 1 downto 0);
            axi4l_wstrb  : in  std_logic_vector((DATA_SIZE / 8) - 1 downto 0);
            axi4l_araddr : in  std_logic_vector(ADDR_SIZE - 1 downto 0);
            axi4l_rdata  : out std_logic_vector(DATA_SIZE - 1 downto 0)
        );
    end component pwm_dac_core;

    -- Time signals
    signal clock_period : time      := 10 ns;

 
    signal pwm_a : std_logic;
    signal pwm_b : std_logic;
    signal pwm_clk : std_logic;
 
    signal axi_aclk    : std_logic                                      := '0';
    signal axi_aresetn : std_logic                                      := '0';
    signal axi_awaddr  : std_logic_vector(ADDR_SIZE - 1 downto 0)       := (others => '0');
    signal axi_awprot  : std_logic_vector(2 downto 0)                   := (others => '0');
    signal axi_awvalid : std_logic                                      := '0';
    signal axi_awready : std_logic                                      := '0';
    signal axi_wdata   : std_logic_vector(DATA_SIZE - 1 downto 0)       := (others => '0');
    signal axi_wstrb   : std_logic_vector((DATA_SIZE / 8) - 1 downto 0) := (others => '0');
    signal axi_wvalid  : std_logic                                      := '0';
    signal axi_wready  : std_logic                                      := '0';
    signal axi_bresp   : std_logic_vector(1 downto 0)                   := (others => '0');
    signal axi_bvalid  : std_logic                                      := '0';
    signal axi_bready  : std_logic                                      := '0';
    signal axi_araddr  : std_logic_vector(ADDR_SIZE - 1 downto 0)       := (others => '0');
    signal axi_arprot  : std_logic_vector(2 downto 0)                   := (others => '0');
    signal axi_arvalid : std_logic                                      := '0';
    signal axi_arready : std_logic                                      := '0';
    signal axi_rdata   : std_logic_vector(DATA_SIZE - 1 downto 0)       := (others => '0');
    signal axi_rresp   : std_logic_vector(1 downto 0)                   := (others => '0');
    signal axi_rvalid  : std_logic                                      := '0';
    signal axi_rready  : std_logic                                      := '0';

begin

    pwm_dac_core_inst : component pwm_dac_core
        generic map(
            DATA_SIZE => DATA_SIZE,
            ADDR_SIZE => ADDR_SIZE
        )
        port map(
            pwm_a        => pwm_a,
            pwm_b        => pwm_b,
            pwm_clk      => pwm_clk,
            axi4l_clk    => axi_aclk,
            axi4l_rst_n  => axi_aresetn,
            axi4l_wdata  => axi_wdata,
            axi4l_awaddr => axi_awaddr,
            axi4l_wstrb  => axi_wstrb,
            axi4l_araddr => axi_araddr,
            axi4l_rdata  => axi_rdata
        );
    
    axi_clock_proc : process is
    begin
        axi_aclk <= '0';
        wait for clock_period / 2;
        axi_aclk <= '1';
        wait for clock_period / 2;
    end process axi_clock_proc;

    uut_proc : process is
    begin
        axi_aresetn <= '0';
        wait for 500 ns;
        axi_aresetn <= '1';
        wait;
    end process uut_proc;
    

end architecture pmw_dac_core_tb_arch;
