---
 -- Copyright (c) 2018 Sean Stasiak. All rights reserved.
 -- Developed by: Sean Stasiak <sstasiak@protonmail.com>
 -- Refer to license terms in license.txt; In the absence of such a file,
 -- contact me at the above email address and I can provide you with one.
---

library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all,
    work.agen_common.all,
    std.env.all;

entity tcnt_tb is
  -- empty
  generic(tclk:time := 10 ns);
end entity;

architecture arch of tcnt_tb is

  component tcnt is
    port( clk_in       : in  std_logic;                         --< clock
          twtck_in     : in  std_logic;                         --< toothed wheel active edge tick input
          runflg_in    : in  std_logic;                         --< allow tooth counting
          loadflg_in   : in  std_logic;                         --< thvl <= thvl_in on next twtck
          rstflg_in    : in  std_logic;                         --< thvl <= 0 on next twtck
          thvl_in      : in  unsigned(TWCNTWIDTH-1 downto 0);   --< thvl load value
          thnb_in      : in  unsigned(TWCNTWIDTH-1 downto 0);   --< number of physical teeth (-1) per wheel rev
          thvl_out     : out unsigned(TWCNTWIDTH-1 downto 0);   --< current tooth value
          gapflg_out   : out std_logic );                       --< gap flag (thnb==thvl)
  end component;

  signal clk      : std_logic;
  signal twtck    : std_logic;
  signal runflg   : std_logic;
  signal loadflg  : std_logic;
  signal rstflg   : std_logic;
  signal thvl_in  : unsigned(TWCNTWIDTH-1 downto 0);
  signal thnb     : unsigned(TWCNTWIDTH-1 downto 0);
  signal thvl_out : unsigned(TWCNTWIDTH-1 downto 0);
  signal gapflg   : std_logic;

  constant WAITCLK : integer := 2;
  signal   clkcnt  : unsigned(15 downto 0) := to_unsigned(0, 16); --< easier to read in sim
begin

  dut : tcnt
    port map( clk_in     => clk,
              twtck_in   => twtck,
              runflg_in  => runflg,
              loadflg_in => loadflg,
              rstflg_in  => rstflg,
              thvl_in    => thvl_in,
              thnb_in    => thnb,
              thvl_out   => thvl_out,
              gapflg_out => gapflg );

  process
  begin
    wait for 1*tclk;
    loadflg <= '0';
    rstflg  <= '0';
    runflg  <= '0';
    thvl_in <= to_unsigned(3, thvl_in'length);
    thnb <= to_unsigned(4, thnb'length);          --<  5 physical teeth
    wait for 3*tclk;
    thvl_in <= to_unsigned(2, thvl_in'length);
    wait for 4*tclk;
    assert thvl_out = to_unsigned(0, thvl_out'length) report "FAIL0";

    -- wait for a couple of twtcks to roll by .. none will be counted
    --
    -- verify:nothing ++'d
    wait until clkcnt = to_unsigned(12, clkcnt'length);
    assert thvl_out = to_unsigned(0, thvl_out'length) report "FAIL1";

    -- start counting ... first edge upon transition to run
    -- will NOT be counted.
    --
    -- verify: thvl_out <= thvl_in on FIRST twedge
    wait until clkcnt = to_unsigned(14, clkcnt'length);
    wait for 1*tclk/10;
    runflg <= '1';
    assert thvl_out = to_unsigned(0, thvl_out'length) report "FAIL2";
    wait for 2*tclk;
    assert thvl_out = thvl_in report "FAIL3";

    -- wait for gap
    --
    -- verify: gap at tooth 4
    wait until gapflg = '1';
    assert clkcnt = to_unsigned(26, clkcnt'length) report "FAIL4";
    assert thvl_out = to_unsigned(4, thvl_out'length) report "FAIL5";
    -- verify gap lasts 1 tooth, and count is reset
    wait until gapflg = '0';
    assert clkcnt = to_unsigned(31, clkcnt'length) report "FAIL6";
    assert thvl_out = to_unsigned(0, thvl_out'length) report "FAIL7";

    -- freerun for a few cycles, drop out of run mode on
    -- twtck in should not be counted
    --
    wait until clkcnt = to_unsigned(65, clkcnt'length);
    wait for 1*tclk/10;
    runflg <= '0';
    assert thvl_out = to_unsigned(1, thvl_out'length) report "FAIL8";
    wait for 8*tclk;
    -- verify: not ++'d and held at last value
    assert thvl_out = to_unsigned(1, thvl_out'length) report "FAIL9";
    wait for 10*tclk;

    -- go back to run mode and verify thvl_out <= thvl_in
    runflg <= '1';
    wait until twtck = '1';
    -- verify: at previous held value still (twtck not sampled yet)
    assert thvl_out = to_unsigned(1, thvl_out'length) report "FAIL10";
    -- verify: thvl_out <= thvl_in on FIRST twedge
    wait for 1*tclk;
    assert thvl_out = thvl_in report "FAIL11";

    -- for now load /reset go unused, therefore untested

    wait for 2*tclk;
    report "DONE"; stop;
  end process;

  process
  begin
    clk <= '0';
    wait for WAITCLK*tclk;
    loop
      clkcnt <= clkcnt +1;
      clk <= '1'; wait for tclk/2;
      clk <= '0'; wait for tclk/2;
    end loop;
  end process;

  process
  begin
    twtck <= '0';
    wait for WAITCLK*tclk;
    wait for 4*tclk;
    wait for 1*tclk/10;     --< introduce a little more realism
    loop
      twtck <= '1'; wait for tclk;
      twtck <= '0'; wait for 4*tclk;
    end loop;
  end process;

end architecture;