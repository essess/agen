---
 -- Copyright (c) 2018 Sean Stasiak. All rights reserved.
 -- Developed by: Sean Stasiak <sstasiak@protonmail.com>
 -- Refer to license terms in license.txt; In the absence of such a file,
 -- contact me at the above email address and I can provide you with one.
---

library ieee;

use ieee.std_logic_1164.all,
    ieee.numeric_std.all;

package agen_pkg is

  --[ defaults ]-----------------------------------------------------
  constant CNTRWIDTH  : integer := 24;          --< counter width
  constant ACNTWIDTH  : integer := CNTRWIDTH;   --< ACNT
  constant PCNTWIDTH  : integer := CNTRWIDTH;   --< PCNT
  constant SCNTWIDTH  : integer := CNTRWIDTH;   --< SCNT
  constant PCNTDEPTH  : integer := 4;           --< buffer the last PCNTDEPTH period measurements
  constant TWCNTWIDTH : integer := 9;           --< count up to 2^TWCNTWIDTH teeth per tw rev
  constant PCNTRSTVAL : integer := 0;           --< reset value for PCNT registers

  --[ types    ]-----------------------------------------------------
  type pcnt_t is array(natural range <>) of unsigned(PCNTWIDTH-1 downto 0);

end package;