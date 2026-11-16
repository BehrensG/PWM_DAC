library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_adc_core is
  generic(
    DATA_SIZE : natural := 32;
    ADDR_SIZE : natural := 4;
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
    axi4l_rdata  : out std_logic_vector(DATA_SIZE - 1 downto 0);

  );
end pwm_adc_core;

architecture pwm_adc_core_arch of pwm_adc_core is

  constant PWM_A_INDEX : std_logic_vector(ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(0, ADDR_SIZE));
  constant PWM_B_INDEX : std_logic_vector(ADDR_SIZE - 1 downto 0) := std_logic_vector(to_unsigned(4, ADDR_SIZE));
  constant PWM_MAX     : natural range 0 to 500000                := 50000;

  signal axi4l_reg_pwm_a : std_logic_vector(DATA_SIZE - 1 downto 0);
  signal axi4l_reg_pwm_b : std_logic_vector(DATA_SIZE - 1 downto 0);
  signal pwm_clock_sig   : std_logic;
  signal pll_locked      : std_logic;

  type   state_t          is (INIT, SYNC, RUN);
  signal state_a, state_b : state_t := INIT;

  procedure pwm_proc(
    variable state   : inout state_t;
    signal   axi_reg : in    std_logic_vector(DATA_SIZE - 1 downto 0);
    signal   pwm_out : out   std_logic) is

    variable pwm_count : natural range 0 to 500000 := 0;
    variable count     : natural range 0 to 500000 := 0;
  begin

    if (axi4l_rst_n = '0') then
      pwm_out <= '1';
      count   := 0;
    else
      case state is
        when INIT =>
          state     := SYNC;
          pwm_count := to_integer(unsigned(axi_reg));
          count     := 0;
          pwm_out   <= '1';
        when SYNC =>
          if (rising_edge(pwm_clock_sig) and count = 0) then
            state := RUN;
          end if;
        when RUN =>
          if (count > PWM_MAX) then
            if (count > pwm_count) then
              pwm_out <= '1';
            else
              pwm_out <= '0';
            end if;
            count := count + 1;
          else
            state := INIT;
          end if;

        when others => null;
      end case;

    end if;

  end procedure pwm_proc;

begin

  pwm_clock_proc : process(all) is
    constant COUNT_MAX_LIMIT : natural range 0 to 500000 := 250000;
    variable count           : unsigned(DATA_SIZE - 1 downto 0);
  begin
    if (axi4l_rst_n = '0') then
      count         := (others => '0');
      pwm_clock_sig <= '0';
    elsif (rising_edge(axi4l_clk)) then
      if (count = COUNT_MAX_LIMIT - 1) then
        count         := (others => '0');
        pwm_clock_sig <= not pwm_clock_sig;
      else
        count := count + 1;
      end if;
    end if;
  end process pwm_clock_proc;

  pll_locked <= '1';

  pwm_clk <= pwm_clock_sig when pll_locked else '0';

  axi4_write : process(all) is
  begin
    if (axi4l_rst_n = '0') then
      axi4l_reg_pwm_a <= std_logic_vector(to_unsigned(0, DATA_SIZE));
      axi4l_reg_pwm_b <= std_logic_vector(to_unsigned(0, DATA_SIZE));
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

end architecture pwm_adc_core_arch;
