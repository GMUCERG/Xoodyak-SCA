library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.NIST_LWAPI_pkg.all;
use work.Design_pkg.all;
use work.xoodyak_constants.all;

entity xoodyak_ctrl is
    port (
        clk             : in   STD_LOGIC;
        rst             : in   STD_LOGIC;
        --PreProcessor===============================================
        ----!key----------------------------------------------------
        key_valid       : in   STD_LOGIC;
        key_ready       : out  STD_LOGIC;
        ----!Data----------------------------------------------------
        bdi_valid       : in   STD_LOGIC;
        bdi_ready       : out  STD_LOGIC;
        bdi_pad_loc     : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_valid_bytes : in   STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
        bdi_eot         : in   STD_LOGIC;
        bdi_eoi         : in   STD_LOGIC;
        bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
        decrypt_in      : in   STD_LOGIC;
        key_update      : in   STD_LOGIC;
        hash_in         : in   std_logic;
        --!Post Processor=========================================
        bdo_valid       : out  STD_LOGIC;
        bdo_ready       : in   STD_LOGIC;
        bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
        bdo_valid_bytes : out  STD_LOGIC_VECTOR (CCWdiv8 -1 downto 0);
        end_of_block    : out  STD_LOGIC;
        msg_auth_valid  : out  STD_LOGIC;
        msg_auth_ready  : in   STD_LOGIC;
        msg_auth        : out  STD_LOGIC;
        --! to datapath
        start_f : out std_logic;
        f_ready : in std_logic;
        f_done : in std_logic;
        init : out std_logic;
        state_en : out std_logic;
        cucd : out std_logic_vector(8 - 1 downto 0);
        wrd_offset : out std_logic_vector(4 - 1 downto 0);
        offset_01 : out std_logic_vector(3 - 1 downto 0);
        state_in_sel : out std_logic_vector(2 -1 downto 0);
        wrd2add_sel : out std_logic_vector(2 - 1 downto 0);
        data_size : out std_logic_vector(3 - 1 downto 0);
        pad_key : out std_logic;
        extract : out std_logic;
        sel_decrypt : out std_logic;
        perm_valid : in std_logic;
        --! from datapath
        tag_neq  : in std_logic;
        --! rdi data form outside world to be used as PRNG seed
        rdi_valid : in std_logic;
        rdi_ready : out std_logic;
        --! tag verif
        cc_tag_valid : out std_logic;
        cc_tag_ready : in std_logic;
        cc_tag_last  : out std_logic;
        tv_done     : in std_logic
--        ;
--        --! PRNG
--        prng_rdi_valid : in std_logic;
--        prng_reseed : out std_logic;
--        en_seed_sipo : out std_logic
    );
end xoodyak_ctrl;

architecture behav of xoodyak_ctrl is

    type state is (S_RST, S_LOAD_SEED, S_START_PRNG, S_WAIT_PRNG, S_IDLE,       -- init
                   S_ABSORB_KEY, S_KEY_UP,                                      -- load key 
                   S_ABSORB_NPUB, S_NPUB_UP,                                    -- absorb npub
                   S_WAIT_AD, S_ABSORB_AD, S_AD_UP, S_ABSORB_AD_DOWN_E,         -- absorb ad
                   S_CRYPT_UP, S_CRYPT_DOWN, S_CRYPT_DOWN_E,                    -- enc/dec
                   S_GEN_TAG, S_OUTPUT_TAG, S_VERIFY_TAG, S_OUTPUT_VERIF_RES    -- tag processing
                  ); 
    signal current_state, next_state : state;
--    type mode_t is (MODE_KEYED, MODE_HASH);
--    signal mode, next_mode : mode_t;
    signal first_blk, next_first_blk : std_logic;
    signal tag_valid, next_tag_valid : std_logic;
    signal bdi_eoi_r, next_bdi_eoi_r : std_logic;
    signal wrd_cnt, next_wrd_cnt : unsigned(5 - 1 downto 0);

begin

    state_reg: process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                current_state <= S_RST;
--                mode <= MODE_HASH;
                first_blk <= '0';
                tag_valid <= '0';
                bdi_eoi_r <= '0';
                wrd_cnt <= (others=>'0');
            else
                current_state <= next_state;
--                mode <= next_mode;
                first_blk <= next_first_blk;
                tag_valid <= next_tag_valid;
                bdi_eoi_r <= next_bdi_eoi_r;
                wrd_cnt <= next_wrd_cnt;
            end if;
        end if;
    end process;

    comb: process(all)
    begin
        --! Default values
        init <= '0';
        wrd2add_sel <= (others=>'0');
        state_en <= '0';
--        add_cu <= '0';
--        add_cd <= '0';
        cucd <= x"00";
        wrd_offset <= (others=>'0');
        offset_01 <= (others=>'0');
        state_in_sel <= (others=>'0');
        data_size <= (others=>'0');
        pad_key <= '0';
        start_f <= '0';
        extract <= '0';
        sel_decrypt <= '0';
        --regs
        next_wrd_cnt <= wrd_cnt;
        next_first_blk <= first_blk;
        next_tag_valid <= tag_valid;
        next_bdi_eoi_r <= bdi_eoi_r;
        next_state <= current_state;
        --
        key_ready <= '0';
        bdi_ready <= '0';
        bdo_valid <= '0';
        bdo_type <= (others=>'0');
        bdo_valid_bytes <= x"0";
        msg_auth_valid <= '0';
        end_of_block <= '0';
        rdi_ready <= '0';
        --
        cc_tag_valid <= '0';
        cc_tag_last <= '0';        
        
        case current_state is
            when S_RST =>
                next_state <= S_IDLE;
                
            ---!============================================ Wait
            when S_IDLE =>
                --clear
                init <= '1';
                state_in_sel <= "10"; --clear state
                state_en <= '1';
                next_tag_valid <= '1';
                next_wrd_cnt <= (others=>'0');
                
                if key_valid = '1' then
                    next_state <= S_ABSORB_KEY;
                else
                    next_state <= S_IDLE;
                end if;
                next_bdi_eoi_r <= '0';
                next_first_blk <= '1';

            --!============================================ KEY
            when S_ABSORB_KEY =>
                wrd2add_sel <= "01";
                wrd_offset <= std_logic_vector(wrd_cnt(3 downto 0));
                data_size <= bdi_size;
                if key_valid = '1' then
                    key_ready <= '1';
                    state_en <= '1';
                    if wrd_cnt = KEY_WORDS - 1 then
                        pad_key <= '1';
                        cucd <= x"02";
                        next_state <= S_KEY_UP;
                    else
                        next_wrd_cnt <= wrd_cnt + 1;
                        next_state <= S_ABSORB_KEY;
                    end if;
                else
                    next_state <= S_ABSORB_KEY;
                end if;

            when S_KEY_UP =>
                state_in_sel <= "01";
                start_f <= '1';
                if perm_valid = '1' then
                    state_en <= '1';
                end if;
                if f_done = '1' then
                    next_state <= S_ABSORB_NPUB;
                    next_wrd_cnt <= (others=>'0');
                else
                    next_state <= S_KEY_UP;
                end if;
                
            --!============================================ NPUB
            when S_ABSORB_NPUB =>
                wrd_offset <= std_logic_vector(wrd_cnt(3 downto 0));
                data_size <= bdi_size;
                if bdi_valid = '1' then
                    bdi_ready <= '1';
                    state_en <= '1';
                    if wrd_cnt = NPUB_WORDS - 1 then
                        offset_01 <= "100";
                        cucd <= x"03";
                        next_state <= S_NPUB_UP;
                        next_wrd_cnt <= (others=>'0');
                    else
                        next_wrd_cnt <= wrd_cnt + 1;
                        next_state <= S_ABSORB_NPUB;
                    end if;
                    next_bdi_eoi_r <= bdi_eoi; --register it
                else
                    next_state <= S_ABSORB_NPUB;
                end if;

            when S_NPUB_UP =>
                state_in_sel <= "01";
                start_f <= '1';
                if perm_valid = '1' then
                    state_en <= '1';
                end if;                
                if f_done = '1' then
                    next_state <= S_WAIT_AD;
                    next_wrd_cnt <= (others=>'0');
                else
                    next_state <= S_NPUB_UP;
                end if;
            
            --!============================================ AD              
            when S_WAIT_AD =>
                if bdi_eoi_r = '1' then
                    next_state <= S_ABSORB_AD_DOWN_E;
                else
                    if bdi_valid = '1' then
                        if bdi_type = HDR_AD then
                                next_state <= S_ABSORB_AD;
                        else
                                next_state <= S_ABSORB_AD_DOWN_E;
                        end if;
                    end if;
                end if;
                
            when S_ABSORB_AD_DOWN_E =>
                -- down empty string
                cucd <= x"03";
                wrd_offset <= (others=>'0');
                wrd2add_sel <= "10";
                state_en <= '1';
                next_state <= S_CRYPT_UP;
            
            when S_ABSORB_AD =>
                wrd_offset <= std_logic_vector(wrd_cnt(3 downto 0));
                data_size <= bdi_size;
                if bdi_valid = '1' then
                    bdi_ready <= '1';
                    state_en <= '1';
                    if bdi_eot = '1' then
                        offset_01 <= bdi_size;
                        if first_blk = '1' then
                            cucd <= x"03";
                        end if;
                        next_state <= S_CRYPT_UP;
                        next_first_blk <= '1'; --get ready for msg
                        next_wrd_cnt <= (others=>'0');
                    else
                        if wrd_cnt = AD_WORDS - 1 then
                            offset_01 <= bdi_size;
                            if first_blk = '1' then
                                cucd <= x"03";
                            end if;
                            next_state <= S_AD_UP;
                            next_wrd_cnt <= (others=>'0');
                            next_first_blk <= '0';
                        else
                            next_wrd_cnt <= wrd_cnt + 1;
                            next_state <= S_ABSORB_AD;
                        end if; 
                    end if;
                else
                    next_state <= S_ABSORB_AD;
                end if;
                
            when S_AD_UP =>
                state_in_sel <= "01";
                start_f <= '1';
                if perm_valid = '1' then
                    state_en <= '1';
                end if;
                if f_done = '1' then
                    next_state <= S_ABSORB_AD;
                    next_wrd_cnt <= (others=>'0');
                else
                    next_state <= S_AD_UP;
                end if;
                            
            --!============================================ CRYPT                
            when S_CRYPT_UP =>
                state_in_sel <= "01";
                if f_ready = '1' then
                    if first_blk = '1' then
                        cucd <= x"80";
                    end if;
                end if;
                start_f <= '1';
                if perm_valid = '1' then
                    state_en <= '1';
                end if;
                if f_done = '1' then
                    if bdi_eoi_r = '1' then
                        next_state <= S_CRYPT_DOWN_E;
                    else
                        next_state <= S_CRYPT_DOWN;
                    end if;
                    next_wrd_cnt <= (others=>'0');
                    next_first_blk <= '0';
                else
                    next_state <= S_CRYPT_UP;
                end if;
                
            when S_CRYPT_DOWN_E =>
                -- down empty string
                wrd_offset <= (others=>'0');
                wrd2add_sel <= "10";
                state_en <= '1';
                next_state <= S_GEN_TAG;
                
            when S_CRYPT_DOWN =>
                bdo_type <= HDR_CT;
                wrd_offset <= std_logic_vector(wrd_cnt(3 downto 0));
                data_size <= bdi_size;
                bdo_valid_bytes <= x"f";
                if decrypt_in = '1' then
                    sel_decrypt <= '1';
                end if;
                if bdi_valid = '1' and bdo_ready = '1' then
                    bdi_ready <= '1';
                    bdo_valid <= '1';
                    state_en <= '1';
                    if bdi_eot = '1' then
                        offset_01 <= bdi_size;
                        next_state <= S_GEN_TAG;
                        next_first_blk <= '1';
                        end_of_block <= '1';
                    else
                        if wrd_cnt = PT_WORDS - 1 then
                            offset_01 <= bdi_size;
                            next_state <= S_CRYPT_UP;
                            next_wrd_cnt <= (others=>'0');
                            next_first_blk <= '0';
                        else
                            next_wrd_cnt <= wrd_cnt + 1;
                            next_state <= S_CRYPT_DOWN;
                        end if; 
                    end if;
                else
                    next_state <= S_CRYPT_DOWN;
                end if;                

            --!==============================================TAG PROCESSING           
            when S_GEN_TAG =>
                --do up
                state_in_sel <= "01";
                -- setting params
                if f_ready = '1' then
                    cucd <= x"40";
                end if;
                start_f <= '1';
                if perm_valid = '1' then
                    state_en <= '1';
                end if;
                if f_done = '1' then
                    if decrypt_in = '1' then
                        next_state <= S_VERIFY_TAG;
                    else
                        next_state <= S_OUTPUT_TAG;
                    end if;
                    next_wrd_cnt <= (others=>'0');
                else
                    next_state <= S_GEN_TAG;
                end if;

            when S_OUTPUT_TAG =>
                bdo_type <= HDR_TAG;
                bdo_valid <= '1';
                bdo_valid_bytes <= x"f";
                extract <= '1';
                wrd_offset <= std_logic_vector(wrd_cnt(3 downto 0));
                if bdo_ready = '1' then
                    if wrd_cnt = TAG_WORDS - 1 then
                        next_state <= S_IDLE;
                        end_of_block <= '1';
                    else
                        next_wrd_cnt <= wrd_cnt + 1;
                        next_state <= S_OUTPUT_TAG; 
                    end if;
                else
                    next_state <= S_OUTPUT_TAG;
                end if;
                
            when S_VERIFY_TAG =>
                wrd_offset <= std_logic_vector(wrd_cnt(3 downto 0));
                bdi_ready <= cc_tag_ready;
                cc_tag_valid <= '1';
                if bdi_valid = '1' and bdi_ready = '1' then
                    if wrd_cnt = TAG_WORDS - 1 then
                        cc_tag_last <= '1';
                        next_state <= S_OUTPUT_VERIF_RES;
                    else
                        next_wrd_cnt <= wrd_cnt + 1;
                        next_state <= S_VERIFY_TAG;
                    end if;
                else
                    next_state <= S_VERIFY_TAG;
                end if;
                
            when S_OUTPUT_VERIF_RES =>
                 if tv_done = '1' then
                    next_state <= S_IDLE;
                 end if;
                
            when others =>
                next_state <= S_IDLE;
        end case;
    end process;
    
    msg_auth <= tag_valid; 

end behav;
