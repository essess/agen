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

entity angcnt_tb is
  -- empty
  generic(tclk:time := 10 ns);
end entity;

architecture dfault of angcnt_tb is

  component angcnt is
    port( clk_in       : in  std_logic;                       --< clock
          twtck_in     : in  std_logic;                       --< toothed wheel active edge tick input
          runflg_in    : in  std_logic;                       --< allow angle step counting
          loadflg_in   : in  std_logic;                       --< acnt <= 0 on next twtck
          rstflg_in    : in  std_logic;                       --< acnt <= acnt_in on next twtck
          stwd_in      : in  std_logic_vector(2 downto 0);    --< step width selector
          prevpcnt_in  : in  unsigned(PCNTWIDTH-1 downto 0);  --< previous tooth period
          acnt_in      : in  unsigned(ACNTWIDTH-1 downto 0);  --< acnt load value
          gapnxtflg_in : in  std_logic;                       --< gap next flag
          gaptcnt_in   : in  std_logic;                       --< num of teeth in gap ('0':1, '1':2)
          ovfflg_out   : out std_logic;                       --< angle count overflow flag
          acnt_out     : out unsigned(ACNTWIDTH-1 downto 0) );--< angle counter
  end component;

  constant CNTRSTVAL : integer := 16#ff_fffc#;

  signal clk       : std_logic;
  signal twtck     : std_logic;
  signal runflg    : std_logic;
  signal loadflg   : std_logic;
  signal rstflg       : std_logic;
  signal stwd      : std_logic_vector(2 downto 0);
  signal prevpcnt  : unsigned(PCNTWIDTH-1 downto 0);
  signal acnt_in   : unsigned(ACNTWIDTH-1 downto 0);
  signal gapnxtflg : std_logic;
  signal gaptcnt   : std_logic;
  signal ovfflg    : std_logic;
  signal acnt_out  : unsigned(ACNTWIDTH-1 downto 0);

  constant WAITCLK : integer := 2;
  signal   clkcnt  : unsigned(15 downto 0) := to_unsigned(0, 16);
begin

  dut : angcnt
    port map( clk_in       => clk,
              twtck_in     => twtck,
              runflg_in    => runflg,
              loadflg_in   => loadflg,
              rstflg_in    => rstflg,
              stwd_in      => stwd,
              prevpcnt_in  => prevpcnt,
              acnt_in      => acnt_in,
              gapnxtflg_in => gapnxtflg,
              gaptcnt_in   => gaptcnt,
              ovfflg_out   => ovfflg,
              acnt_out     => acnt_out );

  process
  begin
    wait for 1*tclk;
    twtck     <= '0';
    gapnxtflg <= '0';
    gaptcnt   <= '0';
    runflg    <= '0';
    rstflg    <= '0';
    loadflg   <= '0';
    stwd      <= "000";  --< step size of 4 to keep waveforms short
    prevpcnt  <= to_unsigned(125, prevpcnt'length);
    acnt_in   <= to_unsigned(12, acnt_in'length);
    wait for 1*tclk;

    -- while runflg deasserted (out of reset), acnt holds at 0
    wait for 5*tclk;
    -- verify: acnt is not counting
    assert acnt_out = to_unsigned(0, acnt_out'length) report "FAIL0";
    acnt_in <= to_unsigned(2, acnt_in'length);

    -- when runflag asserted, acnt still held
    wait for 1*tclk/10;
    runflg <= '1';
    wait for 9*tclk/10;
    wait for 5*tclk;
    assert acnt_out = to_unsigned(0, acnt_out'length) report "FAIL1";

    -- switch to run mode, nothing counted on twtck (but subticks started)
    wait for 5*tclk;
    assert acnt_out = to_unsigned(0, acnt_out'length) report "FAIL2";
    wait for 1*tclk/10;
    twtck <= '1';
    wait for 1*tclk;
    twtck <= '0';
    -- verify: the twtck IS NOT COUNTED
    -- verify: acnt_in loaded to acnt
    assert acnt_out = acnt_in  report "FAIL3";


    -- Need to make sure that the first cycle is still generated
    -- correctly. TWTCK above was captured at clkcnt = 18, therefore
    -- acnt should be 5 by about the 3/4ths of prevcnt from 18.
    --
    -- Go ahead and wait for that exact moment where subtick generation
    -- is halted and generate another twtck and make sure the math is correct
    --
    -- 18+125 = 143
    wait until clkcnt = to_unsigned(142, clkcnt'length);
    -- verify: acnt
    assert acnt_out = to_unsigned(5, acnt_out'length) report "FAIL4";
    -- twtck
    wait for 1*tclk/10;
    twtck <= '1';
    wait for 1*tclk;
    twtck <= '0';
    --
    -- verify: acnt += 1
    assert acnt_out = to_unsigned(6, acnt_out'length) report "FAIL5";


    -- check math for an accel event.
    -- when acnt = 7 (after first subtick) and on the cusp of
    -- the 2nd subtick (7->8 transition), gen a twtck and acnt
    -- should be acnt +=2 plus +1 for the twtck  ->  10
    --
    -- 7->8 happens at clkcnt 206
    wait until clkcnt = to_unsigned(205, clkcnt'length);
    -- verify: acnt
    assert acnt_out = to_unsigned(7, acnt_out'length) report "FAIL6";
    -- twtck
    wait for 1*tclk/10;
    twtck <= '1';
    wait for 1*tclk;
    twtck <= '0';
    --
    -- verify: acnt += 3
    assert acnt_out = to_unsigned(10, acnt_out'length) report "FAIL7";


    -- make sure subticks are halted on decel and math is right
    --
    -- wait for much greater than prevpcnt
    wait until clkcnt = to_unsigned(206+150, clkcnt'length);
    -- verify: acnt is 10+3 = 13  (twtck has not happened yet!)
    assert acnt_out = to_unsigned(13, acnt_out'length) report "FAIL8";


    -- test rst / load ops:
    -- basically goes like this,
    --
    --   when accel happens and rst asserted, then acnt <= 0 on twtck
    --   when decel happens and rst asserted, then acnt <= 0 on twtck
    --
    --   when accel happens and load asserted, then acnt <= acnt_in on twtck
    --   when decel happens and load asserted, then acnt <= acnt_in on twtck
    --
    --  essentially, loads/rsts are sync to twtck and rst has priority over load
    --

    -- while in runflg mode, assert a rstflg and make sure acnt clears
    -- and first twtck IS NOT COUNTED just the same as when runflg
    -- is first asserted
    --


    -- twtck
    wait for 1*tclk/10;
    rstflg <= '1';
    twtck <= '1';
    wait for 1*tclk;
    twtck <= '0';
    --
    -- verify: acnt <= 0 on decel w/rstflg asserted
    assert acnt_out = to_unsigned(0, acnt_out'length) report "FAIL9";

    -- now do the same for accel (exactly on transition from 1->2)
    --
    wait until clkcnt = to_unsigned(419, clkcnt'length);
    assert acnt_out = to_unsigned(1, acnt_out'length) report "FAIL10";
    -- twtck
    wait for 1*tclk/10;
    twtck <= '1';
    wait for 1*tclk;
    rstflg <= '0';
    twtck <= '0';
    --
    -- verify: acnt <= 0 on accel w/rstflg asserted
    assert acnt_out = to_unsigned(0, acnt_out'length) report "FAIL11";
    rstflg <= '0';

    -- good, now do same for loads, decel first
    wait until clkcnt = to_unsigned(419+150, clkcnt'length);
    assert acnt_out = to_unsigned(3, acnt_out'length) report "FAIL12";
    -- twtck
    wait for 1*tclk/10;
    twtck <= '1';
    loadflg <= '1';
    wait for 1*tclk;
    twtck <= '0';
    --
    -- verify: acnt <= acnt_in on decel w/loadlfg asserted
    assert acnt_out = acnt_in report "FAIL13";

    -- now do the same for accel (exactly on transition from 3->4)
    --
    wait until clkcnt = to_unsigned(632, clkcnt'length);
    assert acnt_out = to_unsigned(3, acnt_out'length) report "FAIL14";
    -- twtck
    wait for 1*tclk/10;
    twtck <= '1';
    wait for 1*tclk;
    twtck <= '0';
    --
    -- verify: acnt <= 0 on accel w/rstflg asserted
    assert acnt_out = acnt_in report "FAIL15";
    loadflg <= '0';


    -- drop out of run mode
    wait for 2*tclk;
    runflg <= '0';
    wait for 2*tclk;
    -- verify: acnt holds last value counted
    assert acnt_out = acnt_in report "FAIL16";



    -- TODO: test the use of gapnxtflg and gaptcnt


    wait for 2*tclk;
    report "DONE"; stop;
  end process;

  process
  begin
    wait for WAITCLK*tclk;
    loop
      clkcnt <= clkcnt + to_unsigned(1, clkcnt'length);  --< easier to read in sim
      clk <= '1'; wait for tclk/2;
      clk <= '0'; wait for tclk/2;
    end loop;
  end process;

end architecture;