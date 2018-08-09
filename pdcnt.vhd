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
 -- (P)erio(D) (C)ou(NT) management
---

entity pdcnt is
  generic( PCNTRSTVAL : integer := PCNTRSTVAL );          --<[for testing purposes (ovfflg)]
  port( clk_in     : in  std_logic;                       --<
        twtck_in   : in  std_logic;                       --< toothed wheel active edge tick
        rst_in     : in  std_logic;                       --<
        gapflg_in  : in  std_logic;                       --< gapflag input
        ovfflg_out : out std_logic;                       --< period measurement overflow detected
        pcnt_out   : out pcnt_t(0 to PCNTDEPTH-1) );      --< PCNT
end entity;

architecture dfault of pdcnt is
  constant PCNTMAX : unsigned(PCNTWIDTH-1 downto 0) := (others=>'1');
  signal pcnt : pcnt_t(0 to PCNTDEPTH-1);
begin

  -- NOTE:
  -- overflow is latched until counters are reset as an indicator that you
  -- can't trust anything in the stack of captured tooth period counts

  -- NOTE:
  -- If gapflg asserted, then throwaway the gap period.
  -- We do this to keep subtick generation correct following the gap.

  -----------------------------------------------------------------------------
  pcnt_out <= pcnt;

  process(clk_in)
  begin
    if rising_edge(clk_in) then
      if rst_in = '1' then
        for i in pcnt'range loop
          pcnt(i) <= to_unsigned(PCNTRSTVAL, PCNTWIDTH);
        end loop;
        ovfflg_out <= '0';
      else
        if twtck_in = '1' then        --< pushdown
          if gapflg_in /= '1' then    --  if not in the gap!
            for i in 0 to PCNTDEPTH-2 loop
              pcnt(i+1) <= pcnt(i);
            end loop;
          end if;
          pcnt(0) <= to_unsigned(0, PCNTWIDTH);
        else                          --< cnt++
          if pcnt(0) = PCNTMAX then   --< if already at max cnt then
            ovfflg_out <= '1';        --  overflow is certain this period
          end if;                     --  (latched until rst_in asserted)
          pcnt(0) <= pcnt(0) +1;
        end if;
      end if;
    end if;
  end process;
  -----------------------------------------------------------------------------

end architecture;