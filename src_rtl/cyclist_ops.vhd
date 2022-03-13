library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.design_pkg.all;
use work.xoodyak_constants.all;

entity cyclist_ops is
    generic(
        CONST_ADD : boolean := true
    );
    port(
        clk : in std_logic;
        --! from ctrl 
        din : in std_logic_vector(STATE_SIZE - 1 downto 0);
        dout : out std_logic_vector(STATE_SIZE - 1 downto 0);
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
        --! to ctrl
        tag_neq : out std_logic;
        --! from pre-processor
        bdi           : in  std_logic_vector(CCW  - 1 downto 0);
        bdo           : out std_logic_vector(CCW  - 1 downto 0);
        key           : in  std_logic_vector(CCSW   -1 downto 0)

    );
end cyclist_ops;

architecture behav of cyclist_ops is
	
	attribute keep_hierarchy : string;
	attribute keep_hierarchy of behav : architecture is "true";

    signal state, nxt_state : std_logic_vector(STATE_SIZE - 1 downto 0);
    signal perm_din, perm_dout : std_logic_vector(STATE_SIZE - 1 downto 0);
    signal after_cu_add, after_cd_add : std_logic_vector(STATE_SIZE - 1 downto 0);
    signal after_cu_mux : std_logic_vector(8 - 1 downto 0);
    signal after_cd_mux : std_logic_vector(8 - 1 downto 0);
    signal rndctr : unsigned(4 - 1 downto 0);
    signal state_chunck : std_logic_vector(40 - 1 downto 0);
    signal padded_bdi : std_logic_vector(40 - 1 downto 0);
    signal padded_bdo : std_logic_vector(40 - 1 downto 0);
    signal after_add_mux : std_logic_vector(40 - 1 downto 0);
    signal after_down_mux : std_logic_vector(40 - 1 downto 0);
    signal after_add : std_logic_vector(40 - 1 downto 0);
    signal after_concat_mux : std_logic_vector(384 - 1 downto 0);
    signal after_key_pad_mux : std_logic_vector(8 - 1 downto 0);
    signal after_key_pad_xor : std_logic;
    signal after_key_pad_add : std_logic_vector(384 - 1 downto 0);
    signal bdo_cleared : std_logic_vector(32 - 1 downto 0);
   
begin
    --! state_in_mux
    with state_in_sel select nxt_state <=
         after_cd_add       when "00",
         din                when "01",
         (others=>'0')    when others;       
    
    --! state reg
    state_reg : process(clk)
    begin
        if rising_edge(clk) then
            if state_en = '1' then
                state <= nxt_state;
            end if;
        end if;
    end process;
    
    --! extract_mux
    with wrd_offset select state_chunck <=
        state( 383  downto  352 - 8)  when x"0",
        state( 351  downto  320 - 8)  when x"1",
        state( 319  downto  288 - 8)  when x"2",
        state( 287  downto  256 - 8)  when x"3",
        state( 255  downto  224 - 8)  when x"4",
        state( 223  downto  192 - 8)  when x"5",
        state( 191  downto  160 - 8)  when x"6",
        state( 159  downto  128 - 8)  when x"7",
        state( 127  downto  96  - 8)  when x"8",
        state( 95   downto  64  - 8)  when x"9",
        state( 63   downto  32  - 8)  when others;    
    --! ============================================================ include constant addition
    gen1: if CONST_ADD = true generate
    --! padding with x01
    with offset_01 select padded_bdi <=
        bdi               &       x"00"  when "000",
        bdi(31 downto 24) & x"01000000"  when "001",
        bdi(31 downto 16) &   x"010000"  when "010",
        bdi(31 downto  8) &     x"0100"  when "011",
        bdi(31 downto  0) &       x"01"  when others;
    
    --! select adder input 
    with wrd2add_sel select after_add_mux <=
        padded_bdi                     when   "00",
        key & x"00"                    when   "01",
        x"0100000000"                  when others;

    --! padd bdo
    with offset_01 select padded_bdo <=
        bdo_cleared               &       x"00"  when "000",
        bdo_cleared(31 downto 24) & x"01000000"  when "001",
        bdo_cleared(31 downto 16) &   x"010000"  when "010",
        bdo_cleared(31 downto  8) &     x"0100"  when "011",
        bdo_cleared(31 downto  0) &       x"01"  when others;
    
    after_key_pad_add <= after_concat_mux(383 downto 241) &
                         (after_concat_mux(240) xor pad_key)
                         & after_concat_mux(239 downto 0);
    
    after_cd_add <= after_key_pad_add(383 downto 8) & (cucd xor after_key_pad_add(7 downto 0));
    after_cu_add <= state(383 downto 8) & (cucd xor state(7 downto 0));    
    dout <= after_cu_add;
     
    end generate gen1;
    --! ============================================================No constant addition
    gen2: if CONST_ADD =  false generate
    --! padding with x01
    with offset_01 select padded_bdi <=
        bdi               &       x"00"  when "000",
        bdi(31 downto 24) & x"00000000"  when "001",
        bdi(31 downto 16) &   x"000000"  when "010",
        bdi(31 downto  8) &     x"0000"  when "011",
        bdi(31 downto  0) &       x"00"  when others;

    --! select adder input 
    with wrd2add_sel select after_add_mux <=
        padded_bdi                     when   "00",
        key & x"00"                    when   "01",
        x"0000000000"                  when others;
        
        --! padd bdo
    with offset_01 select padded_bdo <=
        bdo_cleared               &       x"00"  when "000",
        bdo_cleared(31 downto 24) & x"00000000"  when "001",
        bdo_cleared(31 downto 16) &   x"000000"  when "010",
        bdo_cleared(31 downto  8) &     x"0000"  when "011",
        bdo_cleared(31 downto  0) &       x"00"  when others;

        after_cd_add <= after_concat_mux;
        dout <= state;
    end generate gen2;

    --! adder   
    after_add <= after_add_mux xor state_chunck;
    
    --! down_mux
    with sel_decrypt select after_down_mux <=
        after_add                      when    '0',
        padded_bdo  xor state_chunck  when others;
    
    --! clear invalid bytes         
    with data_size select bdo_cleared <=
        (others=>'0')                        when  "000",
        after_add(39 downto 32) & x"000000"  when  "001",
        after_add(39 downto 24) & x"0000"    when  "010",
        after_add(39 downto 16) & x"00"      when  "011",
        after_add(39 downto 8 )              when others; 
    
    --! concat_mux
    with wrd_offset select after_concat_mux <=
                                   after_down_mux & state(351 -8 downto  0)   when x"0",
        state(383  downto  352 ) & after_down_mux & state(319 -8 downto  0)   when x"1",
        state(383  downto  320 ) & after_down_mux & state(287 -8 downto  0)   when x"2",
        state(383  downto  288 ) & after_down_mux & state(255 -8 downto  0)   when x"3",
       
        state(383  downto  256 ) & after_down_mux & state(223 -8 downto  0)   when x"4",
        state(383  downto  224 ) & after_down_mux & state(191 -8 downto  0)   when x"5",
        state(383  downto  192 ) & after_down_mux & state(159 -8 downto  0)   when x"6",
        state(383  downto  160 ) & after_down_mux & state(127 -8 downto  0)   when x"7",
        
        state(383  downto  128 ) & after_down_mux & state(95  -8 downto  0)   when x"8",
        state(383  downto   96 ) & after_down_mux & state(63  -8 downto  0)   when x"9",
        state(383  downto   64 ) & after_down_mux & state(31  -8 downto  0)   when others;

    bdo <= state_chunck(39 downto 8) when extract = '1' else bdo_cleared;
    
    --!WARNING unprotected tag verification
--    tag_neq <= '1' when state_chunck(39 downto 8) /= bdi else '0';
    
end behav;