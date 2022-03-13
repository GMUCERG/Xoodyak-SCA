library ieee;
use ieee.std_logic_1164.all;

entity rho_east is
    port (
        plane0_i : in std_logic_vector(128-1 downto 0);
        plane1_i : in std_logic_vector(128-1 downto 0);
        plane2_i : in std_logic_vector(128-1 downto 0);
        dout : out std_logic_vector(384-1 downto 0)
    );
end rho_east;

architecture behav of rho_east is

	attribute keep_hierarchy : string;
	attribute keep_hierarchy of behav : architecture is "true";

    signal shift1: std_logic_vector(127 downto 0);
    signal shift8: std_logic_vector(127 downto 0);

begin

    --rho_east================================================================
    shift1 <= plane1_i(126 downto 96) & plane1_i(127) &
              plane1_i(94 downto 64)  & plane1_i(95) &
              plane1_i(62 downto 32)  & plane1_i(63) &
              plane1_i(30 downto 0)   & plane1_i(31);
    shift8 <= plane2_i(55 downto 32) & plane2_i(63 downto 56) &
              plane2_i(23 downto 0)  & plane2_i(31 downto 24) &
              plane2_i(119 downto 96) & plane2_i(127 downto 120) &
              plane2_i(87 downto 64) & plane2_i(95 downto 88);
    dout <= shift8 & shift1 & plane0_i;    

end behav;
