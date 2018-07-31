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
 -- (N)oise (F)iltering
---

entity nf is
  port( twraw_in    : in  std_logic;              --< raw toothed wheel input
        clk_in      : in  std_logic;              --<
        rst_in      : in  std_logic;              --<
        acttedge_in : in  std_logic;              --< active tooth edge [GCR2:TED]
        twfilt_out  : out std_logic;              --< corrected/filtered twraw_in (always rising edge active)
        twtck_out   : out std_logic );            --< toothed wheel active edge tick
end entity;

architecture arch of nf is
  signal twfilt : std_logic;
begin

  -----------------------------------------------------------------------------
  twfilt <= twraw_in;                       --< TODO: filtering when needed
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  twfilt_out <= twfilt xor not(acttedge_in);--< tw_in corrected to a standardized
                                            --  active rising edge out for those modules
                                            --  which don't use edge ticks (twtck_out)
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  process(clk_in)                           --< synchronize toothed wheel input and
    variable tw, twtck : std_logic;         --  produce edge tick for downstream modules
  begin
    if rising_edge(clk_in) then
      if rst_in = '1' then
        tw    := twfilt;
        twtck := '0';
      else
        twtck := '0';
        if (tw xor twfilt) = '1' then       --< is edge(tw) ?
          if twfilt = acttedge_in then      --< is active edge ?
            twtck := '1';
          end if;
        end if;
        tw := twfilt;
      end if;
      twtck_out <= twtck;
    end if;
  end process;
  -----------------------------------------------------------------------------

end architecture;