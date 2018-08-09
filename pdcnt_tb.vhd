---
 -- Copyright (c) 2018 Sean Stasiak. All rights reserved.
 -- Developed by: Sean Stasiak <sstasiak@protonmail.com>
 -- Refer to license terms in license.txt; In the absence of such a file,
 -- contact me at the above email address and I can provide you with one.
---

library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all,
    work.agen_pkg.all,
    std.env.all;

entity pdcnt_tb is
  -- empty
  generic(tclk:time := 10 ns);
end entity;

architecture dfault of pdcnt_tb is

  component pdcnt is
    generic( PCNTRSTVAL : integer := PCNTRSTVAL );          --<[for testing purposes (ovfflg)]
    port( clk_in     : in  std_logic;                       --<
          twtck_in   : in  std_logic;                       --< toothed wheel active edge tick
          rst_in     : in  std_logic;                       --<
          gapflg_in  : in  std_logic;                       --< gapflag input
          ovfflg_out : out std_logic;                       --< period measurement overflow detected
          pcnt_out   : out pcnt_t(0 to PCNTDEPTH-1) );      --< PCNT
  end component;

  signal clk    : std_logic;
  signal twtck  : std_logic;
  signal rst    : std_logic;
  signal gapflg : std_logic;
  signal ovfflg : std_logic;
  signal pcnt   : pcnt_t(0 to PCNTDEPTH-1);   --< 4x24 assumption

  constant WAITCLK : integer := 2;
  signal   clkcnt  : unsigned(15 downto 0) := to_unsigned(0, 16); --< easier to read in sim
begin

  dut : pdcnt
    generic map( PCNTRSTVAL => 16#fffffc# )
    port map( clk_in     => clk,
              twtck_in   => twtck,
              rst_in     => rst,
              gapflg_in  => gapflg,
              ovfflg_out => ovfflg,
              pcnt_out   => pcnt );

  process
  begin
    wait for 1*tclk;
    assert PCNTDEPTH = 4;   --< this testbench assumes these defaults
    assert PCNTWIDTH = 24;
    gapflg <= '0';
    rst <= '1';
    twtck <= '0';
    wait for 1*tclk;

    wait for 6*tclk;  --< need to wait for a few clocks (reset is synchronous)

    -- verify dut initial conditions
    assert pcnt(0) = to_unsigned(16#fffffc#, pcnt(0)'length) report "FAIL0.1 : initial conditions";
    assert pcnt(1) = to_unsigned(16#fffffc#, pcnt(1)'length) report "FAIL0.2 : initial conditions";
    assert pcnt(2) = to_unsigned(16#fffffc#, pcnt(2)'length) report "FAIL0.3 : initial conditions";
    assert pcnt(3) = to_unsigned(16#fffffc#, pcnt(3)'length) report "FAIL0.4 : initial conditions";
    assert ovfflg = '0' report "FAIL0.5 : initial conditions";

    rst <= '0';

    wait for 3*tclk;      --< right before roll
    assert pcnt(0) = to_unsigned(16#ffffff#, pcnt(0)'length) report "FAIL1.1";
    assert pcnt(1) = to_unsigned(16#fffffc#, pcnt(1)'length) report "FAIL1.2";
    assert pcnt(2) = to_unsigned(16#fffffc#, pcnt(2)'length) report "FAIL1.3";
    assert pcnt(3) = to_unsigned(16#fffffc#, pcnt(3)'length) report "FAIL1.4";
    assert ovfflg = '0' report "FAIL1.5";
    wait for 1*tclk;      --< BANG!
    assert pcnt(0) = to_unsigned(16#000000#, pcnt(0)'length) report "FAIL2.1";
    assert pcnt(1) = to_unsigned(16#fffffc#, pcnt(1)'length) report "FAIL2.2";
    assert pcnt(2) = to_unsigned(16#fffffc#, pcnt(2)'length) report "FAIL2.3";
    assert pcnt(3) = to_unsigned(16#fffffc#, pcnt(3)'length) report "FAIL2.4";
    assert ovfflg = '1' report "FAIL2.5";
    wait for 1*tclk;
    assert pcnt(0) = to_unsigned(16#000001#, pcnt(0)'length) report "FAIL3.1";
    assert pcnt(1) = to_unsigned(16#fffffc#, pcnt(1)'length) report "FAIL3.2";
    assert pcnt(2) = to_unsigned(16#fffffc#, pcnt(2)'length) report "FAIL3.3";
    assert pcnt(3) = to_unsigned(16#fffffc#, pcnt(3)'length) report "FAIL3.4";
    wait for 3*tclk;

    -- wait for a few ticks and 'push' it down the stack
    twtck <= '1';
    wait for 1*tclk;
    assert pcnt(0) = to_unsigned(16#000000#, pcnt(0)'length) report "FAIL4.1";
    assert pcnt(1) = to_unsigned(16#000004#, pcnt(1)'length) report "FAIL4.2";
    assert pcnt(2) = to_unsigned(16#fffffc#, pcnt(2)'length) report "FAIL4.3";
    assert pcnt(3) = to_unsigned(16#fffffc#, pcnt(3)'length) report "FAIL4.4";
    twtck <= '0';
    wait for 6*tclk;
    -- next shift
    twtck <= '1';
    wait for 1*tclk;
    assert pcnt(0) = to_unsigned(16#000000#, pcnt(0)'length) report "FAIL5.1";
    assert pcnt(1) = to_unsigned(16#000006#, pcnt(1)'length) report "FAIL5.2";
    assert pcnt(2) = to_unsigned(16#000004#, pcnt(2)'length) report "FAIL5.3";
    assert pcnt(3) = to_unsigned(16#fffffc#, pcnt(3)'length) report "FAIL5.4";
    twtck <= '0';
    wait for 4*tclk;
    -- next shift
    twtck <= '1';
    wait for 1*tclk;
    assert pcnt(0) = to_unsigned(16#000000#, pcnt(0)'length) report "FAIL6.1";
    assert pcnt(1) = to_unsigned(16#000004#, pcnt(1)'length) report "FAIL6.2";
    assert pcnt(2) = to_unsigned(16#000006#, pcnt(2)'length) report "FAIL6.3";
    assert pcnt(3) = to_unsigned(16#000004#, pcnt(3)'length) report "FAIL6.4";
    twtck <= '0';
    wait for 7*tclk;
    -- next shift
    twtck <= '1';
    wait for 1*tclk;
    assert pcnt(0) = to_unsigned(16#000000#, pcnt(0)'length) report "FAIL7.1";
    assert pcnt(1) = to_unsigned(16#000007#, pcnt(1)'length) report "FAIL7.2";
    assert pcnt(2) = to_unsigned(16#000004#, pcnt(2)'length) report "FAIL7.3";
    assert pcnt(3) = to_unsigned(16#000006#, pcnt(3)'length) report "FAIL7.4";
    twtck <= '0';
    wait for 2*tclk;
    -- next shift
    twtck <= '1';
    wait for 1*tclk;
    assert pcnt(0) = to_unsigned(16#000000#, pcnt(0)'length) report "FAIL8.1";
    assert pcnt(1) = to_unsigned(16#000002#, pcnt(1)'length) report "FAIL8.2";
    assert pcnt(2) = to_unsigned(16#000007#, pcnt(2)'length) report "FAIL8.3";
    assert pcnt(3) = to_unsigned(16#000004#, pcnt(3)'length) report "FAIL8.4";
    twtck <= '0';

    -- verify: overflow flag is latched until reset!
    assert ovfflg = '1' report "FAIL9";
    wait for 2*tclk;
    rst <= '1';
    wait for 1*tclk;
    assert pcnt(0) = to_unsigned(16#fffffc#, pcnt(0)'length);
    assert pcnt(1) = to_unsigned(16#fffffc#, pcnt(1)'length);
    assert pcnt(2) = to_unsigned(16#fffffc#, pcnt(2)'length);
    assert pcnt(3) = to_unsigned(16#fffffc#, pcnt(3)'length);
    assert ovfflg = '0' report "FAIL10";


    -- TODO: verify pcnt(0) is thrown away while gapflg asserted


    wait for 2*tclk;
    report "DONE"; stop;
  end process;

  process
  begin
    wait for WAITCLK*tclk;
    loop
      clkcnt <= clkcnt +1;
      clk <= '0'; wait for tclk/2;
      clk <= '1'; wait for tclk/2;
    end loop;
  end process;

end architecture;