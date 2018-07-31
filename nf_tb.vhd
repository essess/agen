---
 -- Copyright (c) 2018 Sean Stasiak. All rights reserved.
 -- Developed by: Sean Stasiak <sstasiak@protonmail.com>
 -- Refer to license terms in license.txt; In the absence of such a file,
 -- contact me at the above email address and I can provide you with one.
---

library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all,
    std.env.all;

entity nf_tb is
  -- empty
  generic(tclk:time := 10 ns);
end entity;

architecture arch of nf_tb is

  component nf is
    port( twraw_in    : in  std_logic;              --< raw toothed wheel input
          clk_in      : in  std_logic;              --<
          rst_in      : in  std_logic;              --<
          acttedge_in : in  std_logic;              --< active tooth edge [GCR2:TED]
          twfilt_out  : out std_logic;              --< corrected/filtered twraw_in (always rising edge active)
          twtck_out   : out std_logic );            --< toothed wheel active edge tick
  end component;

  signal twraw    : std_logic;
  signal clk      : std_logic;
  signal acttedge : std_logic;    --< 0 = falling edge, 1 = rising edge
  signal rst      : std_logic;
  signal twfilt   : std_logic;
  signal twtck    : std_logic;

  constant WAITCLK : integer := 2;
  signal   clkcnt  : unsigned(15 downto 0) := to_unsigned(0, 16);
begin

  dut : nf
    port map( twraw_in    => twraw,
              clk_in      => clk,
              rst_in      => rst,
              acttedge_in => acttedge,
              twfilt_out  => twfilt,
              twtck_out   => twtck );

  process
  begin
    wait for 1*tclk;
    rst <= '1';
    wait for 4*tclk;
    assert twtck = '0' report "FAIL0.0 : initial conditions"; --< reset is sync to clk

    acttedge  <= '1'; -- rising -----------------
    -- no edge ticks should be generated while in reset
    twraw <= '0';
    wait until clk = '1';
    twraw <= '1';
    wait until clk = '1';
    assert twtck = '0' report "FAIL1"; -- rise

    twraw <= '1';
    wait until clk = '1';
    twraw <= '0';
    wait until clk = '1';
    assert twtck = '0' report "FAIL2"; -- fall

    acttedge  <= '0'; -- falling ----------------
    -- no edge ticks should be generated while in reset
    twraw <= '0';
    wait until clk = '1';
    twraw <= '1';
    wait until clk = '1';
    assert twtck = '0' report "FAIL3"; -- rise

    twraw <= '1';
    wait until clk = '1';
    twraw <= '0';
    wait until clk = '1';
    assert twtck = '0' report "FAIL4"; -- fall

    twraw <= '0';
    rst <= '0';
    wait for 1*tclk;

    acttedge  <= '1'; -- rising -----------------
    -- detect a twraw rising edge
    -- !!! edge tick is sync'd to rising edge of clk !!!
    -- edge tick duration is one clk cycle
    twraw <= '0';
    wait until clk = '0';
    assert twtck = '0';
    twraw <= '1';
    wait until clk = '0';
    assert twtck = '1' report "FAIL5"; -- rise
    wait for 1*tclk;
    assert twtck = '0' report "FAIL6";

    -- no trigger on twraw falling edge
    twraw <= '1';
    wait until clk = '0';
    twraw <= '0';
    wait until clk = '0';
    assert twtck = '0' report "FAIL7";

    acttedge  <= '0'; -- falling ----------------
    -- detect a twraw falling edge
    -- !!! edge tick is sync'd to rising edge of clk !!!
    -- edge tick duration is one clk cycle
    twraw <= '1';
    wait until clk = '0';
    assert twtck ='0';
    twraw <= '0';
    wait until clk = '0';
    assert twtck = '1' report "FAIL8"; -- fall
    wait for 1*tclk;
    assert twtck = '0' report "FAIL9";

    -- no trigger on twraw rising edge
    twraw <= '0';
    wait until clk = '0';
    twraw <= '1';
    wait until clk = '0';
    assert twtck = '0' report "FAIL10";

    -- TODO: filtering and other stuff when implemented

    wait for 1*tclk;
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