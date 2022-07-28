--===============================================================================================--
--! @file       hpc3_and.vhdl
--! @brief      HPC3 glitch-robust composable 'AND' gadget based on:
--!             D. Knichel and A. Moradi, “Low-Latency Hardware Private Circuits,” 2022, 
--!              https://eprint.iacr.org/2022/507
--!
--! @author     Kamyar Mohajerani
--!
--! @copyright  Copyright (c) 2022 Cryptographic Engineering Research Group
--!             George Mason University, Fairfax, VA, USA
--!             All rights Reserved
--!
--! @license    GNU General Public License v2.0 only (GPL-2.0-only)
--!             https://spdx.org/licenses/GPL-2.0-only.html
--!
--! @vhdl       Compatible with VHDL-2008 and later
--!
--! @note       Appropriate set of synthesis attributes, depending on the synthesis tool, MUST
--!              be set, to prevent optimizations that re-order or remove signals and/or registers
--!
--! @param      G_ORDER: targeted protection order. The number of shares will be `G_ORDER + 1`
--!              - required number of fresh random bits: `G_ORDER * (G_ORDER + 1)`
--!              - latency: 1 cycle
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;

package hpc3_utils_pkg is
    --====================================== Types ==============================================--
    type slv_array is array (natural range <>) of std_logic_vector;

    function to_integer(b : boolean) return natural;
end package;

package body hpc3_utils_pkg is

    function to_integer(b : boolean) return natural is
    begin
        if b then
            return 1;
        else
            return 0;
        end if;
    end function to_integer;

end package body;

library ieee;
use ieee.std_logic_1164.all;

use work.hpc3_utils_pkg.all;

entity hpc3_and is
    generic(
        -- protection order (number of shares = G_ORDER + 1)
        G_ORDER : natural := 1
    );
    port(
        clk : in  std_logic;
        --! clock-enable, enables register updates
        en  : in  std_logic := '1';
        --! inputs 'x' and 'y', each split into `ORDER + 1` shares
        x   : in  std_logic_vector(0 to G_ORDER);
        y   : in  std_logic_vector(0 to G_ORDER);
        --! fresh random input
        r   : in  std_logic_vector(0 to G_ORDER * (G_ORDER + 1) - 1);
        --! output in `ORDER + 1` shares
        z   : out std_logic_vector(0 to G_ORDER)
    );

    --================================= Synthesis Attributes ====================================--
    attribute DONT_TOUCH : string;      -- For Vivado
    -- attribute KEEP       : boolean;

    -- keep the hierarchy/ports
    attribute DONT_TOUCH of hpc3_and : entity is "true";

end entity hpc3_and;

architecture RTL of hpc3_and is

    --==================================== Registers ============================================--
    signal x_reg, xy_reg  : std_logic_vector(0 to G_ORDER);
    signal u1_reg, u2_reg : slv_array(0 to G_ORDER)(0 to G_ORDER);

    --====================================== Wires ==============================================--
    signal c              : slv_array(0 to G_ORDER)(0 to G_ORDER) := (others => (others => '0'));
    signal r1, r2, u1, u2 : slv_array(0 to G_ORDER)(0 to G_ORDER) := (others => (others => '-'));

    --================================= Synthesis Attributes ====================================--
    attribute DONT_TOUCH of RTL : architecture is "true";

    attribute DONT_TOUCH of x_reg, xy_reg, u1_reg, u2_reg : signal is "true";

    -- are these needed???
    attribute DONT_TOUCH of c, r1, r2, u1, u2 : signal is "true";

    -- attribute KEEP of x_reg, xy_reg, u1_reg, u2_reg : signal is TRUE;

begin
    process(all) is
        variable k : natural;
    begin
        k := 0;
        for i in 0 to G_ORDER - 1 loop
            for j in i + 1 to G_ORDER loop
                r1(i)(j) <= r(k);
                r1(j)(i) <= r(k);
                r2(i)(j) <= r(k + 1);
                r2(j)(i) <= r(k + 1);
                k        := k + 2;
            end loop;
        end loop;
    end process;

    GEN_I : for i in 0 to G_ORDER generate
        z(i) <= xy_reg(i) xor (xor c(i));
        GEN_J : for j in 0 to G_ORDER generate
            GEN_I_NE_J : if i /= j generate
                c(i)(j)  <= (x_reg(i) and u1_reg(i)(j)) xor u2_reg(i)(j);
                u1(i)(j) <= y(j) xor r1(i)(j);
                u2(i)(j) <= ((not x(i)) and r1(i)(j)) xor r2(i)(j);
            end generate;
        end generate;
    end generate;

    process(clk) is
    begin
        if rising_edge(clk) and en = '1' then
            x_reg  <= x;
            xy_reg <= x and y;
            u1_reg <= u1;
            u2_reg <= u2;
        end if;
    end process;

end architecture;

--===============================================================================================--

-- HPC3+: Iterated Glitch+Transition-Robust 'AND' Gadget
--    - latency is 2 cycles
--    - requires an additional G_ORDER (total: `G_ORDER * (G_ORDER + 2)`) fresh random bits

library ieee;
use ieee.std_logic_1164.all;

entity hpc3_plus_and is
    generic(
        -- protection order (number of shares = G_ORDER + 1)
        G_ORDER   : natural := 1;
        G_OUT_REG : boolean := TRUE     -- register output (required as a standalone gadget)
    );
    port(
        clk : in  std_logic;
        --! clock-enable, enables register updates
        en  : in  std_logic := '1';
        --! inputs 'x' and 'y', each split into `ORDER + 1` shares
        x   : in  std_logic_vector(0 to G_ORDER);
        y   : in  std_logic_vector(0 to G_ORDER);
        --! fresh random input
        r   : in  std_logic_vector(0 to G_ORDER * (G_ORDER + 2) - 1);
        --! output in `ORDER + 1` shares
        z   : out std_logic_vector(0 to G_ORDER)
    );

    --================================= Synthesis Attributes ====================================--
    attribute DONT_TOUCH : string;      -- For Vivado
    -- attribute KEEP       : boolean;

    -- keep the hierarchy/ports
    attribute DONT_TOUCH of hpc3_plus_and : entity is "true";

end entity;

architecture RTL of hpc3_plus_and is
    signal w, m, m_reg : std_logic_vector(0 to G_ORDER);

    --================================= Synthesis Attributes ====================================--
    attribute DONT_TOUCH of RTL : architecture is "true";
    attribute DONT_TOUCH of w, m, m_reg : signal is "true";
begin
    INST_HPC3 : entity work.hpc3_and
        generic map(G_ORDER => G_ORDER)
        port map(
            clk => clk,
            en  => en,
            x   => x,
            y   => y,
            r   => r(0 to G_ORDER * (G_ORDER + 1) - 1),
            z   => w
        );
    m(0 to G_ORDER - 1) <= r(G_ORDER * (G_ORDER + 1) to G_ORDER * (G_ORDER + 2) - 1);
    m(G_ORDER)          <= xor m(0 to G_ORDER - 1);

    GEN_OUT_REG : if G_OUT_REG generate
        signal z_reg : std_logic_vector(0 to G_ORDER);
        attribute DONT_TOUCH of z_reg : signal is "true";
    begin
        process(clk) is
        begin
            if rising_edge(clk) and en = '1' then
                m_reg <= m;
                z_reg <= w xor m_reg;
            end if;
        end process;
        z <= z_reg;

    else generate
        process(clk) is
        begin
            if rising_edge(clk) and en = '1' then
                m_reg <= m;
            end if;
        end process;
        z <= w xor m_reg;
    end generate;

end architecture;

--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;

use work.hpc3_utils_pkg.all;

entity hpc3_and_vector is
    generic(
        G_ORDER       : natural;        -- protection order (number of shares = G_ORDER + 1)
        G_WIDTH       : positive;       -- width of each input/output share
        G_PLUS        : boolean;        -- use HPC3+ (else use HPC3)
        G_PLUS_OUTREG : boolean
    );
    port(
        clk : in  std_logic;
        --! clock-enable, enables register updates
        en  : in  std_logic := '1';
        --! inputs 'x' and 'y', each split into `ORDER + 1` shares
        x   : in  slv_array(0 to G_ORDER)(G_WIDTH - 1 downto 0);
        y   : in  slv_array(0 to G_ORDER)(G_WIDTH - 1 downto 0);
        --! fresh random input
        r   : in  std_logic_vector(0 to G_WIDTH * G_ORDER * (G_ORDER + 1 + to_integer(G_PLUS)) - 1);
        --! output in `ORDER + 1` shares
        z   : out slv_array(0 to G_ORDER)(G_WIDTH - 1 downto 0)
    );

end entity;

architecture RTL of hpc3_and_vector is
begin

    GEN_INST : for i in 0 to G_WIDTH - 1 generate
        signal xi, yi, zi : std_logic_vector(0 to G_ORDER);
    begin
        GEN_WIRING : for j in 0 to G_ORDER generate
            xi(j)   <= x(j)(i);
            yi(j)   <= y(j)(i);
            z(j)(i) <= zi(j);
        end generate;

        GEN_HPC3 : if G_PLUS generate
            INST_HPC3_PLUS : entity work.hpc3_plus_and
                generic map(
                    G_ORDER   => G_ORDER,
                    G_OUT_REG => G_PLUS_OUTREG
                )
                port map(
                    clk => clk,
                    en  => en,
                    x   => xi,
                    y   => yi,
                    r   => r(i * G_ORDER * (G_ORDER + 2) to (i + 1) * G_ORDER * (G_ORDER + 2) - 1),
                    z   => zi
                );

        else generate
            INST_HPC3 : entity work.hpc3_and
                generic map(G_ORDER => G_ORDER)
                port map(
                    clk => clk,
                    en  => en,
                    x   => xi,
                    y   => yi,
                    r   => r(i * G_ORDER * (G_ORDER + 1) to (i + 1) * G_ORDER * (G_ORDER + 1) - 1),
                    z   => zi
                );

        end generate;
    end generate;

end architecture;
