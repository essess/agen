---
 -- Copyright (c) 2018 Sean Stasiak. All rights reserved.
 -- Developed by: Sean Stasiak <sstasiak@protonmail.com>
 -- Refer to license terms in license.txt; In the absence of such a file,
 -- contact me at the above email address and I can provide you with one.
---

library ieee;
use ieee.std_logic_1164.all,
    ieee.numeric_std.all,
    work.agen_common.all;

---
 -- (T)ooth (C)ou(NT) management
---

entity tcnt is
  port( clk_in        : in  std_logic;                          --< clock
        twtck_in      : in  std_logic;                          --< toothed wheel active edge tick input
        runflg_in     : in  std_logic;                          --< allow tooth counting
        loadflg_in    : in  std_logic;                          --< thvl <= thvl_in on next twtck
        rstflg_in     : in  std_logic;                          --< thvl <= 0 on next twtck
        thvl_in       : in  unsigned(TWCNTWIDTH-1 downto 0);    --< thvl load value
        thnb_in       : in  unsigned(TWCNTWIDTH-1 downto 0);    --< number of physical teeth (-1) per wheel rev
        thvl_out      : out unsigned(TWCNTWIDTH-1 downto 0);    --< current tooth value
        gapflg_out    : out std_logic;                          --< gap flag (thnb==thvl)
        gapnxtflg_out : out std_logic );                        --< next tooth period is a gap
end entity;

architecture default of tcnt is
  type state_t is (LOADTHVL, COUNT);
begin

  -----------------------------------------------------------------------------
  process(clk_in)
    variable state : state_t := LOADTHVL;
    variable thvl : unsigned(TWCNTWIDTH-1 downto 0) := to_unsigned(0, TWCNTWIDTH);
  begin
    if rising_edge(clk_in) then
      if runflg_in = '0' then
        gapflg_out    <= '0';
        gapnxtflg_out <= '0';
        state := LOADTHVL; --< 'others'
      else
        case state is
          when COUNT =>
            if twtck_in = '1' then
              gapflg_out    <= '0';
              gapnxtflg_out <= '0';
              if rstflg_in = '1' then                 --< rst / load / count ?
                thvl := to_unsigned(0, thvl'length);
              elsif loadflg_in = '1' then
                thvl := thvl_in;
              else
                thvl := thvl +1;
              end if;
              if thvl > thnb_in then                  --< rollover ?
                thvl := to_unsigned(0, thvl'length);
              end if;
              if thvl = (thnb_in-to_unsigned(1, thnb_in'length)) then
                gapnxtflg_out <= '1';     --< next tooth period is expected to be a gap
              elsif thvl = thnb_in then
                gapflg_out <= '1';        --< should be in gap right now
              end if;
            end if;
          when others =>--< forced load on twtck upon transition to run
            gapflg_out    <= '0';
            gapnxtflg_out <= '0';
            if twtck_in = '1' then
              thvl := thvl_in;
              state := COUNT;
            end if;
        end case;
      end if;
      thvl_out <= thvl;
    end if;
  end process;
  -----------------------------------------------------------------------------

end architecture;