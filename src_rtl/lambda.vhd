
library ieee;
use ieee.std_logic_1164.all;
use work.xoodyak_constants.all;

entity lambda is
    port (
        rnd_const : in std_logic_vector(12-1 downto 0);
        din : in std_logic_vector(STATE_SIZE-1 downto 0);
        plane0_o : out std_logic_vector(PLANE_SIZE-1 downto 0);
        plane1_o : out std_logic_vector(PLANE_SIZE-1 downto 0);
        plane2_o : out std_logic_vector(PLANE_SIZE-1 downto 0)
    );
end lambda;

architecture behav of lambda is
	attribute dont_touch : string;
	attribute dont_touch of behav : architecture is "true";
	
    signal p_plane :std_logic_vector(128-1 downto 0);
	signal eshift :std_logic_vector(128-1 downto 0);
	
	signal add_rnd_const_small: std_logic_vector(11 downto 0);
	signal shift0_plane1: std_logic_vector(127 downto 0);
    signal shift11_plane2: std_logic_vector(127 downto 0);
	
	signal shift1: std_logic_vector(127 downto 0);
    signal shift8: std_logic_vector(127 downto 0);
    --
    signal theta_o0, theta_o1, theta_o2 : std_logic_vector(127 downto 0);
    signal iota_o0, iota_o1, iota_o2 : std_logic_vector(127 downto 0);
    signal rhow_o0, rhow_o1, rhow_o2 : std_logic_vector(127 downto 0);
    signal chi_o0, chi_o1, chi_o2 : std_logic_vector(127 downto 0);
    
    signal plane0 :std_logic_vector(128-1 downto 0);
    signal plane1 :std_logic_vector(128-1 downto 0);
    signal plane2 :std_logic_vector(128-1 downto 0);

begin

    plane0 <= din(127 downto 0);
    plane1 <= din(255 downto 128);
    plane2 <= din(383 downto 256);
    --theta=================================================================
    p_plane <= plane0 xor plane1 xor plane2;
    eshift <= (p_plane(26 downto 0) & p_plane(31 downto 27) &
          p_plane(122 downto 96) & p_plane(127 downto 123) &
          p_plane(90 downto 64) & p_plane(95 downto 91) &
          p_plane(58 downto 32) & p_plane(63 downto 59)) xor
          (p_plane (17 downto 0) & p_plane(31 downto 18) &
          p_plane (113 downto 96) & p_plane(127 downto 114) &
          p_plane (81 downto 64) & p_plane(95 downto 82) &
          p_plane (49 downto 32) & p_plane(63 downto 50));          
    theta_o2 <= plane2 xor eshift;
    theta_o1 <= plane1 xor eshift;
    theta_o0 <= plane0 xor eshift;

    --iota===================================================================
    add_rnd_const_small <= theta_o0(107 downto 96) xor rnd_const;
    iota_o0 <= theta_o0(127 downto 108) & add_rnd_const_small & theta_o0(95 downto 0);
    iota_o1 <= theta_o1;
    iota_o2 <= theta_o2;
    
    --rho_west================================================================
    shift0_plane1 <= iota_o1(31 downto 0) & iota_o1(127 downto 32);
    shift11_plane2 <= iota_o2(116 downto 96) & iota_o2(127 downto 117) &
               iota_o2(84 downto 64) & iota_o2(95 downto 85) &
               iota_o2(52 downto 32) & iota_o2(63 downto 53) &
               iota_o2(20 downto 0) & iota_o2(31 downto 21);
    rhow_o0 <= iota_o0;
    rhow_o1 <= shift0_plane1;
    rhow_o2 <= shift11_plane2;
    
    plane0_o <= rhow_o0;
    plane1_o <= rhow_o1;
    plane2_o <= rhow_o2;
    
end behav;
