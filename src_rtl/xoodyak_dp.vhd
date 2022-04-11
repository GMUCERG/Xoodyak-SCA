library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.design_pkg.all;
use work.xoodyak_constants.all;

entity xoodyak_dp is
    port(
        clk : in std_logic;
        --! from ctrl 
        start_f : in std_logic;
        f_ready : out std_logic;
        f_done : out std_logic;
        init : in std_logic;
        state_en : in std_logic;
        cucd : in std_logic_vector(8 - 1 downto 0);
        wrd_offset : in std_logic_vector(4 - 1 downto 0);
        offset_01 : in std_logic_vector(3 - 1 downto 0);
        state_in_sel : in std_logic_vector(2 -1 downto 0);
        wrd2add_sel : in std_logic_vector(2 - 1 downto 0);
        data_size : in std_logic_vector(3 - 1 downto 0);
        pad_key : in std_logic;
        extract : in std_logic;
        sel_decrypt : in std_logic;
        perm_valid : out std_logic;
        --! to ctrl
        tag_neq : out std_logic;
        --! from pre-processor
        bdi0           : in  std_logic_vector(CCW  - 1 downto 0);
        bdi1           : in  std_logic_vector(CCW  - 1 downto 0);
        bdo0           : out std_logic_vector(CCW  - 1 downto 0);
        bdo1           : out std_logic_vector(CCW  - 1 downto 0);
        key0           : in  std_logic_vector(CCSW   -1 downto 0);
        key1           : in  std_logic_vector(CCSW   -1 downto 0);
        tag0           : out std_logic_vector(CCW  - 1 downto 0);
        tag1           : out std_logic_vector(CCW  - 1 downto 0);
        --! from prng
        prng_rdi_data : in std_logic_vector(STATE_SIZE - 1 downto 0)
    );
end xoodyak_dp;

architecture behav of xoodyak_dp is
    attribute keep_hierarchy : string;
	attribute keep_hierarchy of behav : architecture is "true";

    --! Domain0
    signal perm_din0, perm_dout0 : std_logic_vector(STATE_SIZE - 1 downto 0);
    --! Domain1
    signal perm_din1, perm_dout1 : std_logic_vector(STATE_SIZE - 1 downto 0);
    
    attribute keep : string;
    attribute keep of perm_din0,perm_dout0  : signal is "true";
    attribute keep of perm_din1,perm_dout1  : signal is "true";
begin
    --! Permuation exists in both domains.
    xoodoo_pr : entity work.xoodoo_round_pr(behav)
    port map (
        clk => clk,
        init => init,
        en => start_f,
        perm_valid => perm_valid,
        ready => f_ready,
        done => f_done,
        prng_rdi_data => prng_rdi_data,
        input0 => perm_din0,
        input1 => perm_din1,
        perm_output0 => perm_dout0,
        perm_output1 => perm_dout1
    );

    --!===========================================================DOMAIN0
    cyc_ops0: entity work.cyclist_ops(behav)
    generic map(
        CONST_ADD => true
    )
    port map(
        clk => clk,
        --! from ctrl 
        din => perm_dout0,
        dout => perm_din0,
        state_en => state_en,
        cucd => cucd,
        wrd_offset => wrd_offset,
        offset_01 => offset_01,
        state_in_sel => state_in_sel,
        wrd2add_sel => wrd2add_sel,
        data_size => data_size,
        pad_key => pad_key,
        extract => extract,
        sel_decrypt => sel_decrypt,
        --! to ctrl
        tag_neq => open, -- not used
        --! from pre-processor
        bdi => bdi0,
        bdo => bdo0,
        key => key0,
        tag => tag0
    );
	--!===========================================================DOMAIN1
    cyc_ops1: entity work.cyclist_ops(behav)
    generic map(
        CONST_ADD => false
    )
    port map(
        clk => clk,
        --! from ctrl 
        din => perm_dout1,
        dout => perm_din1,
        state_en => state_en,
        cucd => x"00",
        wrd_offset => wrd_offset,
        offset_01 => offset_01,
        state_in_sel => state_in_sel,
        wrd2add_sel => wrd2add_sel,
        data_size => data_size,
        pad_key => '0', --pad_key,
        extract => extract,
        sel_decrypt => sel_decrypt,
        --! to ctrl
        tag_neq => open, -- not used
        --! from pre-processor
        bdi => bdi1,
        bdo => bdo1,
        key => key1,
        tag => tag1
    );
      
end behav;
