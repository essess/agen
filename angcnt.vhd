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
 -- (ANG)le (C)ou(NT) management
---

entity angcnt is
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
end entity;

architecture dfault of angcnt is
  type state_t is (LOADACNT, HOLD, COUNT);
  subtype sel_t is std_logic_vector(1 downto 0);

  signal K : unsigned(10 downto 0);       --< easiest to match tckc
  signal tckc_in : unsigned(10 downto 0); --< see note
begin

  -- NOTE:
  -- make sure tckc can handle 4x the step width in order to handle gaps of
  -- at least size 3 (I have ideas for the future)
  --        512x4-> 2048 ->log_2(2048) is 11 bits

  -----------------------------------------------------------------------------
  with stwd_in select --< determine step width, aka K
    K <= to_unsigned(4  , K'length) when "000",
         to_unsigned(8  , K'length) when "001",
         to_unsigned(16 , K'length) when "010",
         to_unsigned(32 , K'length) when "011",
         to_unsigned(64 , K'length) when "100",
         to_unsigned(128, K'length) when "101",
         to_unsigned(256, K'length) when "110",
         to_unsigned(512, K'length) when others;

  with sel_t'(gapnxtflg_in & gaptcnt_in) select
    tckc_in <= (K sll 1)+K when "11",   --< 3x K, 2 missing teeth
               (K sll 1)   when "10",   --< 2x K, 1 missing tooth
               (K)         when others; --< 1x K
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- basic idea here,
  -- ignore the world until runflg_in asserted, then wait for a toothed wheel
  -- edge to roll in as a gating function for sub tick generation
  --
  -- when no more subticks to generate in this tooth period, put self on
  -- hold until the next toothed wheel input edge arrives
  --
  process(clk_in)
    variable state : state_t := LOADACNT;
    variable scnt : unsigned(SCNTWIDTH-1 downto 0) := to_unsigned(0, SCNTWIDTH);
    variable acnt : unsigned(ACNTWIDTH-1 downto 0) := to_unsigned(0, ACNTWIDTH);
    variable tckc : unsigned(tckc_in'range);
  begin
    if rising_edge(clk_in) then
      if runflg_in = '0' then
        state := LOADACNT; --< 'others'
      else
        case state is
          when COUNT =>
            if (twtck_in = '1') and (tckc /= to_unsigned(0, tckc'length)) then --< accel ?
                acnt := acnt +tckc;           --< beware: acnt is not monotonic!
                scnt := to_unsigned(0, scnt'length);
                tckc := tckc_in;
                if rstflg_in = '1' then       --< ugly, but MUST be handled here
                  acnt := to_unsigned(0, acnt'length);
                elsif loadflg_in = '1' then
                  acnt := acnt_in;
                end if;
            else                              --< counting off subticks until finished
              scnt := scnt +K;
              if scnt >= prevpcnt_in then     --< scnt overflow? (or = for last subtick)
                scnt := scnt -prevpcnt_in;    --< compensate for non integer PCNT(1)/K values
                acnt := acnt +1;
                tckc := tckc -1;
                if tckc = to_unsigned(1, tckc'length) then
                  state := HOLD;              --< HOLD on last subtick
                end if;
              end if;
            end if;
          when HOLD =>  --< eval for resets and loads sync to twtck
            scnt := to_unsigned(0, scnt'length);
            tckc := tckc_in;
            if twtck_in = '1' then
              if rstflg_in = '1' then
                acnt := to_unsigned(0, acnt'length);
              elsif loadflg_in = '1' then
                acnt := acnt_in;
              else      --< neither load or reset desired, ++ on twtck
                acnt := acnt +1;
              end if;
              state := COUNT;
            end if;
          when others =>--< forced load on twtck upon transition to run
            scnt := to_unsigned(0, scnt'length);
            tckc := tckc_in;
            if twtck_in = '1' then
              acnt := acnt_in;
              state := COUNT;
            end if;
        end case;
      end if;
      acnt_out <= acnt;
    end if;
  end process;

  ovfflg_out <= '0';      --< it's impossible to ovf acnt with current K and
                          --  thnb limits  (512*512 = 262144 (18 bits))
  -- YO!: Would be nice to figure out some kind of VHDL compile time assert
  --      for this.
  -----------------------------------------------------------------------------

end architecture;