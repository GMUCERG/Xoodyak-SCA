library ieee;
use ieee.std_logic_1164.all;

package sca_gadgets_pkg is
    pure function num_rand_bits(GADGET : string; G_WIDTH : positive; G_ORDER : positive) return integer;

end package;

package body sca_gadgets_pkg is

    pure function num_rand_bits(GADGET : string; G_WIDTH : positive; G_ORDER : positive) return integer is
    begin
        if GADGET = "DOM" then
            return G_WIDTH * (G_ORDER) * (G_ORDER + 1) / 2;
        elsif GADGET = "HPC3" then
            return G_WIDTH * G_ORDER * (G_ORDER + 1);
        elsif GADGET = "HPC3+" then
            return G_WIDTH * G_ORDER * (G_ORDER + 2);
        else
            return -1;
        end if;
    end function;

end package body;

library ieee;
use ieee.std_logic_1164.all;

use work.sca_gadgets_pkg.all;
use work.hpc3_utils_pkg.all;

entity chi384 is
    generic(
        G_AND_GADGET : STRING
    );
    port(
        clk  : in  std_logic;
        en   : in  std_logic;
        rnd  : in  std_logic_vector(3 * num_rand_bits(G_AND_GADGET, 128, 1) - 1 downto 0);
        --domain0
        A0_0 : in  std_logic_vector(128 - 1 downto 0);
        A1_0 : in  std_logic_vector(128 - 1 downto 0);
        A2_0 : in  std_logic_vector(128 - 1 downto 0);
        O0_0 : out std_logic_vector(128 - 1 downto 0);
        O1_0 : out std_logic_vector(128 - 1 downto 0);
        O2_0 : out std_logic_vector(128 - 1 downto 0);
        --domain1
        A0_1 : in  std_logic_vector(128 - 1 downto 0);
        A1_1 : in  std_logic_vector(128 - 1 downto 0);
        A2_1 : in  std_logic_vector(128 - 1 downto 0);
        O0_1 : out std_logic_vector(128 - 1 downto 0);
        O1_1 : out std_logic_vector(128 - 1 downto 0);
        O2_1 : out std_logic_vector(128 - 1 downto 0)
    );
end chi384;

architecture behav of chi384 is

    attribute dont_touch : string;
    attribute dont_touch of behav : architecture is "true";

    --delayed signals -- used to fully pipeline Chi.
    signal A0_0_d : std_logic_vector(128 - 1 downto 0);
    signal A1_0_d : std_logic_vector(128 - 1 downto 0);
    signal A2_0_d : std_logic_vector(128 - 1 downto 0);

    signal A0_1_d : std_logic_vector(128 - 1 downto 0);
    signal A1_1_d : std_logic_vector(128 - 1 downto 0);
    signal A2_1_d : std_logic_vector(128 - 1 downto 0);
    ----
    signal nA0_1  : std_logic_vector(128 - 1 downto 0);
    signal nA1_1  : std_logic_vector(128 - 1 downto 0);
    signal nA2_1  : std_logic_vector(128 - 1 downto 0);

    signal B0_0 : std_logic_vector(128 - 1 downto 0);
    signal B1_0 : std_logic_vector(128 - 1 downto 0);
    signal B2_0 : std_logic_vector(128 - 1 downto 0);

    signal B0_1 : std_logic_vector(128 - 1 downto 0);
    signal B1_1 : std_logic_vector(128 - 1 downto 0);
    signal B2_1 : std_logic_vector(128 - 1 downto 0);

    attribute keep : string;
    attribute keep of A0_0_d : signal is "true";
    attribute keep of A1_0_d : signal is "true";
    attribute keep of A2_0_d : signal is "true";

    attribute keep of A0_1_d : signal is "true";
    attribute keep of A1_1_d : signal is "true";
    attribute keep of A2_1_d : signal is "true";

    attribute keep of nA0_1 : signal is "true";
    attribute keep of nA1_1 : signal is "true";
    attribute keep of nA2_1 : signal is "true";

    attribute keep of B0_0 : signal is "true";
    attribute keep of B1_0 : signal is "true";
    attribute keep of B2_0 : signal is "true";

    attribute keep of B0_1 : signal is "true";
    attribute keep of B1_1 : signal is "true";
    attribute keep of B2_1 : signal is "true";

begin
    nA0_1 <= not A0_1;
    nA1_1 <= not A1_1;
    nA2_1 <= not A2_1;

    GEN_AND_GADGETS : if G_AND_GADGET = "DOM" generate

        and0 : entity work.and_dom_n(behav)
            generic map(N => 128)
            port map(
                clk => clk,
                en  => en,
                X0  => A1_0,
                X1  => nA1_1,
                Y0  => A2_0,
                Y1  => A2_1,
                Z   => rnd(127 downto 0),
                Q0  => B0_0,
                Q1  => B0_1
            );

        and1 : entity work.and_dom_n(behav)
            generic map(N => 128)
            port map(
                clk => clk,
                en  => en,
                X0  => A2_0,
                X1  => nA2_1,
                Y0  => A0_0,
                Y1  => A0_1,
                Z   => rnd(255 downto 128),
                Q0  => B1_0,
                Q1  => B1_1
            );

        and2 : entity work.and_dom_n(behav)
            generic map(N => 128)
            port map(
                clk => clk,
                en  => en,
                X0  => A0_0,
                X1  => nA0_1,
                Y0  => A1_0,
                Y1  => A1_1,
                Z   => rnd(383 downto 256),
                Q0  => B2_0,
                Q1  => B2_1
            );

    elsif G_AND_GADGET = "HPC3+" generate
        constant G_ORDER : integer  := 1;
        constant G_WIDTH : integer  := 128;
        constant G_PLUS  : boolean  := TRUE;
        constant RAND_W  : positive := num_rand_bits(G_AND_GADGET, G_WIDTH, G_ORDER);

        function join(a, b : std_logic_vector) return slv_array is
            variable res : slv_array(0 to G_ORDER)(G_WIDTH - 1 downto 0);
        begin
            res(0) := a;
            res(1) := b;
            return res;
        end function;

        signal B0, B1, B2 : slv_array(0 to G_ORDER)(G_WIDTH - 1 downto 0);
    begin

        and0 : entity work.hpc3_and_vector
            generic map(
                G_ORDER       => G_ORDER,
                G_WIDTH       => G_WIDTH,
                G_PLUS        => G_PLUS,
                G_PLUS_OUTREG => FALSE
            )
            port map(
                clk => clk,
                en  => en,
                x   => join(A1_0, nA1_1),
                y   => join(A2_0, A2_1),
                r   => rnd(RAND_W - 1 downto 0),
                z   => B0
            );
        B0_0 <= B0(0);
        B0_1 <= B0(1);

        and1 : entity work.hpc3_and_vector
            generic map(
                G_ORDER       => G_ORDER,
                G_WIDTH       => G_WIDTH,
                G_PLUS        => G_PLUS,
                G_PLUS_OUTREG => FALSE
            )
            port map(
                clk => clk,
                en  => en,
                x   => join(A2_0, nA2_1),
                y   => join(A0_0, A0_1),
                r   => rnd(2 * RAND_W - 1 downto RAND_W),
                z   => B1
            );
        B1_0 <= B1(0);
        B1_1 <= B1(1);

        and2 : entity work.hpc3_and_vector
            generic map(
                G_ORDER       => G_ORDER,
                G_WIDTH       => G_WIDTH,
                G_PLUS        => G_PLUS,
                G_PLUS_OUTREG => FALSE
            )
            port map(
                clk => clk,
                en  => en,
                x   => join(A0_0, nA0_1),
                y   => join(A1_0, A1_1),
                r   => rnd(3 * RAND_W - 1 downto 2 * RAND_W),
                z   => B2
            );
        B2_0 <= B2(0);
        B2_1 <= B2(1);

    else generate
        assert false report "unsupported value for G_AND_GADGET" severity failure;
    end generate;

    --insert register to avoid combinational loops
    reg : process(clk)
    begin
        if rising_edge(clk) then
            if en = '1' then
                A0_0_d <= A0_0;
                A1_0_d <= A1_0;
                A2_0_d <= A2_0;
                A0_1_d <= A0_1;
                A1_1_d <= A1_1;
                A2_1_d <= A2_1;
            end if;
        end if;
    end process;

    O0_0 <= A0_0_d xor B0_0;
    O1_0 <= A1_0_d xor B1_0;
    O2_0 <= A2_0_d xor B2_0;

    O0_1 <= A0_1_d xor B0_1;
    O1_1 <= A1_1_d xor B1_1;
    O2_1 <= A2_1_d xor B2_1;

end behav;
