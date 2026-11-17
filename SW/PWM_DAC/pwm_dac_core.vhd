library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_dac_core is
  generic(
    DATA_SIZE : natural := 32;
    ADDR_SIZE : natural := 4
  );
  port(
    -- PWM_DAC --
    pwm_a        : out std_logic;
    pwm_b        : out std_logic;
    pwm_clk      : out std_logic;
    -- AXI 4 Lite --
    axi4l_clk    : in  std_logic;
    axi4l_rst_n  : in  std_logic;
    -- Write data --
    axi4l_wdata  : in  std_logic_vector(DATA_SIZE - 1 downto 0);
    axi4l_awaddr : in  std_logic_vector(ADDR_SIZE - 1 downto 0);
    axi4l_wstrb  : in  std_logic_vector((DATA_SIZE / 8) - 1 downto 0);
    -- Read data --
    axi4l_araddr : in  std_logic_vector(ADDR_SIZE - 1 downto 0);
    axi4l_rdata  : out std_logic_vector(DATA_SIZE - 1 downto 0)
  );
end pwm_dac_core;

architecture pwm_dac_core_arch of pwm_dac_core is

  constant PWM_A_INDEX : std_logic_vector(ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(0, ADDR_SIZE));
  constant PWM_B_INDEX : std_logic_vector(ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(4, ADDR_SIZE));
  constant PWM_MAX     : natural range 0 to 1000000               := 500000;

  signal axi4l_reg_pwm_a : std_logic_vector(DATA_SIZE - 1 downto 0);
  signal axi4l_reg_pwm_b : std_logic_vector(DATA_SIZE - 1 downto 0);
  signal pwm_clock_reg   : std_logic;
  signal pll_locked      : std_logic;
  signal pwm_a_reg       : std_logic;
  signal pwm_b_reg       : std_logic;

  type   state_t                  is (SYNC, RUN);
  signal state_a, state_b         : state_t                    := SYNC;
  signal count_a, count_b         : natural range 0 to 1000000 := 0;
  signal pwm_count_a, pwm_count_b : natural range 0 to 1000000 := 0;
  signal pwm_tick                 : std_logic                  := '0';
  signal pwm_sync                 : std_logic_vector(2 downto 0) := (others => '0');

  procedure pwm_procedure(
    signal state     : inout state_t;
    signal axi_reg   : in    std_logic_vector(DATA_SIZE - 1 downto 0);
    signal pwm_out   : inout std_logic;
    signal pwm_count : inout natural range 0 to 1000000;
    signal count     : inout natural range 0 to 1000000
  ) is

  begin

    if (axi4l_rst_n = '0') then
      count   <= 0;
      pwm_out <= '0';
    else
      case state is
        when SYNC =>
          if (pwm_tick = '1' and count = 0) or (count = 0 and pwm_sync(0) = '1') then
            state <= RUN;
          else
            pwm_count <= to_integer(unsigned(axi_reg));
            count     <= 0;
            pwm_out   <= '0';
          end if;
        when RUN =>
          if (count < PWM_MAX - 2) then
            if (count < pwm_count) then
              pwm_out <= '1';
            else
              pwm_out <= '0';
            end if;
            count <= count + 1;
          else
            count <= 0;
            state <= SYNC;
          end if;

        when others => null;
      end case;

    end if;

  end procedure pwm_procedure;

begin

  pwm_clock_proc : process(all) is
    constant COUNT_MAX_LIMIT : natural range 0 to 500000 := 250000;
    variable count           : unsigned(DATA_SIZE - 1 downto 0);
  begin
    if (axi4l_rst_n = '0') then
      count         := (others => '0');
      pwm_clock_reg <= '0';
      pwm_tick      <= '0';
    elsif (rising_edge(axi4l_clk)) then
      if (count = COUNT_MAX_LIMIT - 1) then
        count         := (others => '0');
        pwm_clock_reg <= not pwm_clock_reg;
      else
        count := count + 1;

      end if;
      if (count = COUNT_MAX_LIMIT - 2) then
        pwm_tick <= '1';
      else
        pwm_tick <= '0';
      end if;
    end if;
  end process pwm_clock_proc;

  pll_locked <= '1';

  pwm_clk <= pwm_clock_reg when pll_locked else '0';
  

  pwm_a <= pwm_a_reg;
  pwm_b <= pwm_b_reg;

  axi4_write : process(all) is
  begin
    if (axi4l_rst_n = '0') then
      axi4l_reg_pwm_a <= std_logic_vector(to_unsigned(250000, DATA_SIZE));
      axi4l_reg_pwm_b <= std_logic_vector(to_unsigned(400000, DATA_SIZE));
    elsif rising_edge(axi4l_clk) then
      if axi4l_awaddr = PWM_A_INDEX then
        for i in 0 to 3 loop
          if (axi4l_wstrb(i)) then
            axi4l_reg_pwm_a((i * 8 + 7) downto (i * 8)) <= axi4l_wdata((i * 8 + 7) downto (i * 8));
          end if;
        end loop;
      elsif axi4l_awaddr = PWM_B_INDEX then
        for i in 0 to 3 loop
          if (axi4l_wstrb(i)) then
            axi4l_reg_pwm_b((i * 8 + 7) downto (i * 8)) <= axi4l_wdata((i * 8 + 7) downto (i * 8));
          end if;
        end loop;
      end if;
    end if;
  end process axi4_write;

  axi4l_rdata <= axi4l_reg_pwm_a when (axi4l_araddr = PWM_A_INDEX) else
                 axi4l_reg_pwm_b when (axi4l_awaddr = PWM_B_INDEX) else
                 (others => '0');

  pwm_proc : process(all) is
  begin
    if (axi4l_rst_n = '0') then
      state_a <= SYNC;
      state_b <= SYNC;
    elsif rising_edge(axi4l_clk) then
      pwm_sync <= pwm_sync(1 downto 0) & pwm_tick;
      pwm_procedure(state => state_a, axi_reg => axi4l_reg_pwm_a, pwm_out => pwm_a_reg, pwm_count => pwm_count_a, count => count_a);
      pwm_procedure(state => state_b, axi_reg => axi4l_reg_pwm_b, pwm_out => pwm_b_reg, pwm_count => pwm_count_b, count => count_b);
    end if;

  end process pwm_proc;

end architecture pwm_dac_core_arch;
