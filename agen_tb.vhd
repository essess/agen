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

entity agen_tb is
  -- empty
  generic(tclk:time := 10 ns);
end entity;

architecture arch of agen_tb is

  component agen is                                                  --[ reference ]
    port( clk_in         : in  std_logic;                         --<
          twraw_in       : in  std_logic;                         --< raw toothed wheel input
          rst_in         : in  std_logic;                         --<
          angrstflg_in   : in  std_logic;                         --< 'like' GCR2:ARST
          acttedge_in    : in  std_logic;                         --< GCR2:TED
          runflg_in      : in  std_logic;                         --< GCR2:STRT
          stwd_in        : in  std_logic_vector(2 downto 0);      --< STWD
          thnb_in        : in  unsigned(TWCNTWIDTH-1 downto 0);   --< THNB
          acnt_in        : in  unsigned(ACNTWIDTH-1 downto 0);    --< ACNT wr (loaded on re of start)
          thvl_in        : in  unsigned(TWCNTWIDTH-1 downto 0);   --< THVL wr (loaded on re of start)
          gaptcnt_in     : in  std_logic;                         --< num of teeth expected in next gap ('0':1, '1':2)
          pcntovfflg_out : out std_logic;                         --< INT:0
          twtck_out      : out std_logic;                         --< INT:2
          twfilt_out     : out std_logic;                         --<
          acntovfflg_out : out std_logic;                         --< INT:3
          gapflg_out     : out std_logic;                         --< INT:6
          gapnxtflg_out  : out std_logic;                         --<
          acnt_out       : out unsigned(ACNTWIDTH-1 downto 0);    --< ACNT rd
          pcnt_out       : out pcnt_t(0 to PCNTDEPTH-1);          --< PCNT
          thvl_out       : out unsigned(TWCNTWIDTH-1 downto 0) ); --< THVL rd
  end component;

  signal clk        : std_logic;
  signal twraw      : std_logic;
  signal rst        : std_logic;
  signal angrstflg  : std_logic;
  signal acttedge   : std_logic;   --< 0 falling edge, 1 rising edge
  signal runflg     : std_logic;
  signal stwd       : std_logic_vector(2 downto 0);
  signal thnb       : unsigned(TWCNTWIDTH-1 downto 0);
  signal acnt_in    : unsigned(ACNTWIDTH-1 downto 0);
  signal thvl_in    : unsigned(TWCNTWIDTH-1 downto 0);
  signal gaptcnt    : std_logic;   --< ('0':1, '1':2)
  signal pcntovfflg : std_logic;
  signal twtck      : std_logic;
  signal twfilt     : std_logic;
  signal acntovfflg : std_logic;
  signal gapflg     : std_logic;
  signal gapnxtflg  : std_logic;
  signal acnt_out   : unsigned(ACNTWIDTH-1 downto 0);
  signal pcnt       : pcnt_t(0 to PCNTDEPTH-1);
  signal thvl_out   : unsigned(TWCNTWIDTH-1 downto 0);

  constant WAITCLK : integer := 2;
  signal   clkcnt  : unsigned(15 downto 0) := to_unsigned(0, 16);
begin

  dut : agen
    port map( clk_in         => clk,
              twraw_in       => twraw,
              rst_in         => rst,
              angrstflg_in   => angrstflg,
              acttedge_in    => acttedge,
              runflg_in      => runflg,
              stwd_in        => stwd,
              thnb_in        => thnb,
              acnt_in        => acnt_in,
              thvl_in        => thvl_in,
              gaptcnt_in     => gaptcnt,
              pcntovfflg_out => pcntovfflg,
              twtck_out      => twtck,
              twfilt_out     => twfilt,
              acntovfflg_out => acntovfflg,
              gapflg_out     => gapflg,
              gapnxtflg_out  => gapnxtflg,
              acnt_out       => acnt_out,
              pcnt_out       => pcnt,
              thvl_out       => thvl_out );

  process
  begin
    wait for 1*tclk;
    rst       <= '1';
    angrstflg <= '0';
    acttedge  <= '0';     --< input falling edge active
    gaptcnt   <= '0';     --< gap is only 1 tooth wide
    runflg    <= '0';
    stwd      <= "000";   --< step size of 4 to keep waveforms short/readable
    thnb      <= to_unsigned(35-1, thnb'length);
    acnt_in   <= to_unsigned(0, acnt_in'length);
    thvl_in   <= to_unsigned(0, thvl_in'length);
    wait for 4*tclk;
    rst <= '0';

    wait until clkcnt = 755;
    wait until clk = '0';
    -- at this point, we just saw the gap.
    -- the timestamp for the most recent tooth is larger than the one before it
    --
    -- verify: gap captured, and we're where we should be
    assert pcnt(1) > pcnt(2) report "FAIL1";

    -- because we know where we're at, setup everything and let it run
    -- (we still have to watch for the next gap --- we'll get to it)
    --
    -- do: we're at physical tooth 1 (logical 0), so tooth 2 is our next one.
    --     set the initial tooth value (the next one we're expecting)
    --     to its logical value
    thvl_in <= to_unsigned(1, thvl_in'length);

    -- do: on this next tooth, we know its angle count is 4 (based on selected stwd)
    --
    acnt_in <= to_unsigned(4, acnt_in'length);

    -- that's all we need to do, now let it 'go' -> put it in run mode
    runflg <= '1';

    -- hang out until gapflg asserts
    assert gapflg = '0' report "FAIL2";
    wait until gapflg = '1';
    wait until clk = '0';

    -- verify: we're at logical tooth 34
    assert thvl_out = to_unsigned(34, thvl_out'length) report "FAIL3";
    --
    -- because we're on this tooth, we need to signal to the angle
    -- counter that it needs to reset on the next toothed wheel
    -- active adge arrival
    --
    -- do: assert acnt reset flag (anytime before that edge arrives)
    angrstflg <= '1';

    -- ffwd to next edge arrival and check terminal count
    --
    wait until twtck = '1';
    wait until clk = '0';
    -- verify: at terminal count  TEETH*K = 144 (-1, zero based)
    assert acnt_out = to_unsigned(143, acnt_out'length) report "FAIL4";


    wait until gapflg = '0';  --< thvl has reset itself
    wait until clk = '0';
    -- deassert angrstflg
    angrstflg <= '0';

    -- on and on ...
    -- YO!: test accel/decel on gap to make sure it works
    --      (I've done this informally, make it formal!)

    wait for 4*tclk;
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

  process
      constant HIGH  : integer := 10; --< tclk's
      constant LOW   : integer := 10; --< tclk's
      constant TEETH : integer := 35; --< 36-1
      constant GAP   : integer := 1;
  begin
    twraw <= '1';
    wait for 30*tclk;
    wait for 2*tclk/10;
    loop
      for i in 1 to (TEETH-1) loop        --< gen teeth
        twraw <= '0'; wait for LOW*tclk;
        twraw <= '1'; wait for HIGH*tclk;
      end loop;
      for i in 1 to GAP loop              --< gen gap
        twraw <= '0'; wait for 2*LOW*tclk;
        twraw <= '1'; wait for 2*HIGH*tclk;
      end loop;
    end loop;
  end process;

end architecture;