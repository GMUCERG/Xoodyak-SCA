library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.xoodyak_constants.all;

entity xoodoo_round_pr is
	port(
	    clk : in std_logic;
	    init : in std_logic;
	    en : in std_logic;
	    perm_valid : out std_logic;
	    done : out std_logic;
	    ready : out std_logic;
		input0: in std_logic_vector(STATE_SIZE-1 downto 0);
		input1: in std_logic_vector(STATE_SIZE-1 downto 0);
		perm_output0: out std_logic_vector(STATE_SIZE-1 downto 0);
		perm_output1: out std_logic_vector(STATE_SIZE-1 downto 0);
		--prng data
		prng_rdi_data : std_logic_vector(STATE_SIZE - 1 downto 0)
    );
end xoodoo_round_pr;

architecture behav of xoodoo_round_pr is

	attribute dont_touch : string;
	attribute dont_touch of behav : architecture is "true";

    signal chi_o0_0, chi_o1_0, chi_o2_0 : std_logic_vector(127 downto 0);
    signal chi_o0_1, chi_o1_1, chi_o2_1 : std_logic_vector(127 downto 0);
    

    signal lambda_o0_0, lambda_o1_0, lambda_o2_0 : std_logic_vector(127 downto 0);
    signal lambda_o0_1, lambda_o1_1, lambda_o2_1 : std_logic_vector(127 downto 0);

    
	                                     
	signal si0, si_rev0, so0, so_rev0, dout_t0, din_t0 : std_logic_vector(STATE_SIZE -1 downto 0);
	signal si1, si_rev1, so1, so_rev1, dout_t1, din_t1 : std_logic_vector(STATE_SIZE -1 downto 0);
	
	attribute keep : string;
    attribute keep of si0, si_rev0, so0, so_rev0, dout_t0, din_t0  : signal is "true";
    attribute keep of si1, si_rev1, so1, so_rev1, dout_t1, din_t1  : signal is "true";
    
    attribute keep of chi_o0_0, chi_o1_0, chi_o2_0  : signal is "true";
    attribute keep of chi_o0_1, chi_o1_1, chi_o2_1  : signal is "true";
    attribute keep of lambda_o0_0, lambda_o1_0, lambda_o2_0  : signal is "true";
    attribute keep of lambda_o0_1, lambda_o1_1, lambda_o2_1  : signal is "true";
    
    
    signal rnd_const : std_logic_vector(12 - 1 downto 0);

	-- Ci round constants rom
	type rom_array is array (0 to 12) of std_logic_vector(12 - 1 downto 0); 
	constant rnd_const_rom: rom_array :=(x"058", x"038", x"3C0", x"0D0", 
	                                     x"120", x"014", x"060", x"02C", 
	                                     x"380", x"0F0", x"1A0", x"012", 
	                                     others => x"000");
	
	--! control logic signals
	signal rndctr : unsigned(4 - 1 downto 0);
--    signal en_rndctr : std_logic;
    
    signal wait_cnt  : unsigned(4-1 downto 0);
    signal en_wait_cnt : std_logic;
    signal clr : std_logic;
    
    
    signal input0_s, input1_s :  std_logic_vector(STATE_SIZE-1 downto 0);
    signal  sel_in : std_logic;
    
begin
    --! control logic. Not security sensitive========================================
    --! round counter
    round_conter: process(clk)
    begin
        if rising_edge(clk) then
            if clr = '1' or (rndctr = NUM_ROUNDS and en = '1') then
                rndctr <= (others=>'0');
            else
                if en = '1' then
                    rndctr <= rndctr + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- perm_valid <= en;    
    perm_valid <= done;    
    ready <= '1' when (rndctr = 0) else '0';
    done <= '1' when (rndctr = NUM_ROUNDS and en = '1') else '0';
    clr <= '1' when (init = '1' or (rndctr = NUM_ROUNDS and en = '1')) else '0';
    sel_in  <= '1' when rndctr > 0 else '0';
    --! end control logic===========================================================
    
    input0_s <= so_rev0 when sel_in = '1' else input0;
    input1_s <= so_rev1 when sel_in = '1' else input1;
    
    --invert byte ordering 
    si0 <= input0_s(127 downto 0) & input0_s(255 downto 128) & input0_s(383 downto 256);
    gen_map0: for i in 0 to 384/(4*8) -1 generate
            si_rev0((i*4 + 0)*8 + 8 -1 downto (i*4 + 0)*8) <= si0((i*4 + 3)*8 + 8 -1 downto (i*4 + 3)*8);
            si_rev0((i*4 + 1)*8 + 8 -1 downto (i*4 + 1)*8) <= si0((i*4 + 2)*8 + 8 -1 downto (i*4 + 2)*8);
            si_rev0((i*4 + 2)*8 + 8 -1 downto (i*4 + 2)*8) <= si0((i*4 + 1)*8 + 8 -1 downto (i*4 + 1)*8);
            si_rev0((i*4 + 3)*8 + 8 -1 downto (i*4 + 3)*8) <= si0((i*4 + 0)*8 + 8 -1 downto (i*4 + 0)*8);
    end generate gen_map0;
    
    si1 <= input1_s(127 downto 0) & input1_s(255 downto 128) & input1_s(383 downto 256);
    gen_map1: for i in 0 to 384/(4*8) -1 generate
            si_rev1((i*4 + 0)*8 + 8 -1 downto (i*4 + 0)*8) <= si1((i*4 + 3)*8 + 8 -1 downto (i*4 + 3)*8);
            si_rev1((i*4 + 1)*8 + 8 -1 downto (i*4 + 1)*8) <= si1((i*4 + 2)*8 + 8 -1 downto (i*4 + 2)*8);
            si_rev1((i*4 + 2)*8 + 8 -1 downto (i*4 + 2)*8) <= si1((i*4 + 1)*8 + 8 -1 downto (i*4 + 1)*8);
            si_rev1((i*4 + 3)*8 + 8 -1 downto (i*4 + 3)*8) <= si1((i*4 + 0)*8 + 8 -1 downto (i*4 + 0)*8);
    end generate gen_map1;
    
    --!------------------------------------------------------------------------------------------------

    rnd_const <= rnd_const_rom(to_integer(unsigned(rndctr)));
    
    --!==========================================================================
    lmbd0: entity work.lambda(behav)
    port map (
        rnd_const => rnd_const,
        din=> si_rev0,
        plane0_o  => lambda_o0_0,
        plane1_o  => lambda_o1_0,
        plane2_o  => lambda_o2_0
    );
    
    lmbd1: entity work.lambda(behav)
    port map (
        rnd_const => (others=>'0'),
        din=> si_rev1,
        plane0_o  => lambda_o0_1,
        plane1_o  => lambda_o1_1,
        plane2_o  => lambda_o2_1
    );
       
    --!==========================================================================
    chi: entity work.chi384(behav)
    port map (
        clk => clk,
        rnd => prng_rdi_data,
        init => clr,
        en => en,
        --domain0
        A0_0 => lambda_o0_0,
        A1_0 => lambda_o1_0,
        A2_0 => lambda_o2_0,
        O0_0 => chi_o0_0,
        O1_0 => chi_o1_0,
        O2_0 => chi_o2_0,
        --domain1
        A0_1 => lambda_o0_1,
        A1_1 => lambda_o1_1,
        A2_1 => lambda_o2_1,
        O0_1 => chi_o0_1,
        O1_1 => chi_o1_1,
        O2_1 => chi_o2_1
    );
    --!==========================================================================
    rho_east0: entity work.rho_east(behav)
    port map(
        plane0_i => chi_o0_0,
        plane1_i => chi_o1_0,
        plane2_i => chi_o2_0,
        dout => dout_t0
    );
    
    rho_east1: entity work.rho_east(behav)
    port map(
        plane0_i => chi_o0_1,
        plane1_i => chi_o1_1,
        plane2_i => chi_o2_1,
        dout => dout_t1
    );
    
    --fix byte ordering
    so0 <= dout_t0(127 downto 0) & dout_t0(255 downto 128) & dout_t0(383 downto 256) ;
    gen_invmap0: for j in 0 to 384/(4*8) -1 generate
            so_rev0((j*4 + 0)*8 + 8 -1 downto (j*4 + 0)*8) <= so0((j*4 + 3)*8 + 8 -1 downto (j*4 + 3)*8);
            so_rev0((j*4 + 1)*8 + 8 -1 downto (j*4 + 1)*8) <= so0((j*4 + 2)*8 + 8 -1 downto (j*4 + 2)*8);
            so_rev0((j*4 + 2)*8 + 8 -1 downto (j*4 + 2)*8) <= so0((j*4 + 1)*8 + 8 -1 downto (j*4 + 1)*8);
            so_rev0((j*4 + 3)*8 + 8 -1 downto (j*4 + 3)*8) <= so0((j*4 + 0)*8 + 8 -1 downto (j*4 + 0)*8);
    end generate gen_invmap0;
    
    so1 <= dout_t1(127 downto 0) & dout_t1(255 downto 128) & dout_t1(383 downto 256) ;
    gen_invmap1: for j in 0 to 384/(4*8) -1 generate
            so_rev1((j*4 + 0)*8 + 8 -1 downto (j*4 + 0)*8) <= so1((j*4 + 3)*8 + 8 -1 downto (j*4 + 3)*8);
            so_rev1((j*4 + 1)*8 + 8 -1 downto (j*4 + 1)*8) <= so1((j*4 + 2)*8 + 8 -1 downto (j*4 + 2)*8);
            so_rev1((j*4 + 2)*8 + 8 -1 downto (j*4 + 2)*8) <= so1((j*4 + 1)*8 + 8 -1 downto (j*4 + 1)*8);
            so_rev1((j*4 + 3)*8 + 8 -1 downto (j*4 + 3)*8) <= so1((j*4 + 0)*8 + 8 -1 downto (j*4 + 0)*8);
    end generate gen_invmap1;
    
    perm_output0 <= so_rev0;   
    perm_output1 <= so_rev1;   
    
end behav;
