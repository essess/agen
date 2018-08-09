---
 -- Copyright (c) 2018 Sean Stasiak. All rights reserved.
 -- Developed by: Sean Stasiak <sstasiak@protonmail.com>
 -- Refer to license terms in license.txt; In the absence of such a file,
 -- contact me at the above email address and I can provide you with one.
---

library ieee;

use ieee.std_logic_1164.all,
    ieee.numeric_std.all,
    work.agen_pkg.all;

---
 -- (A)ngle (GEN)erator
 --
 --   Pull the strings on this thing correctly and you can use any toothed
 --   wheel with any number of gaps as long as teeth are equidistant
 --
 --   It looks a lot like TI's HWAG, but it's not. Some of their documentation
 --   may help you understand the AGEN better.
---

entity agen is                                                  --[ reference ]
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
end entity;

architecture dfault of agen is

  component nf is
    port( twraw_in    : in  std_logic;                          --< raw toothed wheel input
          clk_in      : in  std_logic;                          --<
          rst_in      : in  std_logic;                          --<
          acttedge_in : in  std_logic;                          --< active tooth edge [GCR2:TED]
          twfilt_out  : out std_logic;                          --< corrected/filtered twraw_in (always rising edge active)
          twtck_out   : out std_logic );                        --< toothed wheel active edge tick
  end component;

  component pdcnt is
    port( clk_in     : in  std_logic;                           --<
          twtck_in   : in  std_logic;                           --< toothed wheel active edge tick
          rst_in     : in  std_logic;                           --<
          gapflg_in  : in  std_logic;                           --< gapflag input
          ovfflg_out : out std_logic;                           --< period measurement overflow detected
          pcnt_out   : out pcnt_t(0 to PCNTDEPTH-1) );          --< PCNT
  end component;

  component tcnt is
    port( clk_in        : in  std_logic;                        --< clock
          twtck_in      : in  std_logic;                        --< toothed wheel active edge tick input
          runflg_in     : in  std_logic;                        --< allow tooth counting
          loadflg_in    : in  std_logic;                        --< thvl <= thvl_in on next twtck
          rstflg_in     : in  std_logic;                        --< thvl <= 0 on next twtck
          thvl_in       : in  unsigned(TWCNTWIDTH-1 downto 0);  --< thvl load value
          thnb_in       : in  unsigned(TWCNTWIDTH-1 downto 0);  --< number of physical teeth (-1) per wheel rev
          thvl_out      : out unsigned(TWCNTWIDTH-1 downto 0);  --< current tooth value
          gapflg_out    : out std_logic;                        --< gap flag (thnb==thvl)
          gapnxtflg_out : out std_logic );                      --< next tooth period is a gap
  end component;

  component angcnt is
    port( clk_in       : in  std_logic;                       --< clock
          twtck_in     : in  std_logic;                       --< toothed wheel active edge tick input
          runflg_in    : in  std_logic;                       --< allow angle step counting
          loadflg_in   : in  std_logic;                       --< acnt <= acnt_in on next twtck
          rstflg_in    : in  std_logic;                       --< acnt <= 0 on next twtck
          stwd_in      : in  std_logic_vector(2 downto 0);    --< step width selector
          prevpcnt_in  : in  unsigned(PCNTWIDTH-1 downto 0);  --< previous tooth period
          acnt_in      : in  unsigned(ACNTWIDTH-1 downto 0);  --< acnt load value
          gapnxtflg_in : in  std_logic;                       --< gap next flag
          gaptcnt_in   : in  std_logic;                       --< num of teeth in gap ('0':1, '1':2)
          ovfflg_out   : out std_logic;                       --< angle count overflow flag
          acnt_out     : out unsigned(ACNTWIDTH-1 downto 0) );--< angle counter
  end component;

  signal twtck, twfilt, gapflg, gapnxtflg : std_logic;
  signal pcnt : pcnt_t(0 to PCNTDEPTH-1);
begin

  -----------------------------------------------------------------------------
  twtck_out  <= twtck;
  twfilt_out <= twfilt;

  nf0 : nf
    port map( twraw_in    => twraw_in,
              clk_in      => clk_in,
              rst_in      => rst_in,
              acttedge_in => acttedge_in,
              twfilt_out  => twfilt,
              twtck_out   => twtck );
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  pcnt_out <= pcnt;

  pdcnt0 : pdcnt
    port map( clk_in     => clk_in,
              twtck_in   => twtck,
              rst_in     => rst_in,
              gapflg_in  => gapflg,
              ovfflg_out => pcntovfflg_out,
              pcnt_out   => pcnt );
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  gapflg_out <= gapflg;
  gapnxtflg_out <= gapnxtflg;

  tcnt0 : tcnt
    port map( clk_in        => clk_in,
              twtck_in      => twtck,
              runflg_in     => runflg_in,
              loadflg_in    => '0',           --< unused/unexposed
              rstflg_in     => '0',           --< unused/unexposed
              thvl_in       => thvl_in,
              thnb_in       => thnb_in,
              thvl_out      => thvl_out,
              gapflg_out    => gapflg,
              gapnxtflg_out => gapnxtflg );
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- NOTE:
  -- don't assert runflg while in gap -- it works, but you'll use the
  -- gap's period for prevpcnt during the first tooth period and therefore
  -- subtick generation is wrong.

  angcnt0 : angcnt
    port map( clk_in       => clk_in,
              twtck_in     => twtck,
              runflg_in    => runflg_in,
              loadflg_in   => '0',          --< unused/unexposed
              rstflg_in    => angrstflg_in,
              stwd_in      => stwd_in,
              prevpcnt_in  => pcnt(1),      --< SEE NOTE ABOVE
              acnt_in      => acnt_in,
              gapnxtflg_in => gapnxtflg,
              gaptcnt_in   => gaptcnt_in,
              ovfflg_out   => acntovfflg_out,
              acnt_out     => acnt_out );
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------

end architecture;