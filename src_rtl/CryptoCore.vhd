library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;
use work.xoodyak_constants.all;
use work.design_pkg.AND_GADGET;

entity CryptoCore_SCA is
    generic(
        G_AND_GADGET : string := AND_GADGET
    );
    port(
        clk             : in  STD_LOGIC;
        rst             : in  STD_LOGIC;
        key             : in  STD_LOGIC_VECTOR(SDI_SHARES * CCSW - 1 downto 0);
        key_update      : in  STD_LOGIC;
        key_valid       : in  STD_LOGIC;
        key_ready       : out STD_LOGIC;
        bdi             : in  STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
        bdi_valid       : in  STD_LOGIC;
        bdi_ready       : out STD_LOGIC;
        bdi_pad_loc     : in  STD_LOGIC_VECTOR(CCW / 8 - 1 downto 0);
        bdi_valid_bytes : in  STD_LOGIC_VECTOR(CCW / 8 - 1 downto 0);
        bdi_size        : in  STD_LOGIC_VECTOR(3 - 1 downto 0);
        bdi_eot         : in  STD_LOGIC;
        bdi_eoi         : in  STD_LOGIC;
        bdi_type        : in  STD_LOGIC_VECTOR(4 - 1 downto 0);
        decrypt_in      : in  STD_LOGIC;
        hash_in         : in  std_logic;
        bdo             : out STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
        bdo_valid       : out STD_LOGIC;
        bdo_ready       : in  STD_LOGIC;
        bdo_type        : out STD_LOGIC_VECTOR(4 - 1 downto 0);
        bdo_valid_bytes : out STD_LOGIC_VECTOR(CCW / 8 - 1 downto 0);
        end_of_block    : out STD_LOGIC;
        --
        msg_auth_valid  : out STD_LOGIC;
        msg_auth_ready  : in  STD_LOGIC;
        msg_auth        : out STD_LOGIC;
        --! Random Input
        rdi             : in  std_logic_vector(CCRW - 1 downto 0);
        rdi_valid       : in  std_logic;
        rdi_ready       : out std_logic
    );
end entity CryptoCore_SCA;

architecture behavioral of CryptoCore_SCA is
    --! ctrl signals
    signal start_f      : std_logic;
    signal init         : std_logic;
    signal state_en     : std_logic;
    signal cucd         : std_logic_vector(8 - 1 downto 0);
    signal wrd_offset   : std_logic_vector(4 - 1 downto 0);
    signal offset_01    : std_logic_vector(3 - 1 downto 0);
    signal state_in_sel : std_logic_vector(2 - 1 downto 0);
    signal wrd2add_sel  : std_logic_vector(2 - 1 downto 0);
    signal data_size    : std_logic_vector(3 - 1 downto 0);
    signal pad_key      : std_logic;
    signal f_ready      : std_logic;
    signal f_done       : std_logic;
    signal extract      : std_logic;
    signal sel_decrypt  : std_logic;
    signal tag_neq      : std_logic;
    signal perm_valid   : std_logic;

    signal cc_tag_valid : std_logic;
    signal cc_tag_ready : std_logic;
    signal cc_tag_last  : std_logic;
    signal cc_tag       : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    -- DEBUG
    --    signal DEBUG_cc_tag : std_logic_vector(CCW - 1 downto 0);
    --    signal DEBUG_expected_tag : std_logic_vector(CCW - 1 downto 0);

begin

    --! datapath
    dp : entity work.xoodyak_dp(behav)
        generic map(
            G_AND_GADGET => G_AND_GADGET
        )
        port map(
            clk           => clk,
            --! from ctrl 
            start_f       => start_f,
            f_ready       => f_ready,
            f_done        => f_done,
            init          => init,
            state_en      => state_en,
            cucd          => cucd,
            wrd_offset    => wrd_offset,
            offset_01     => offset_01,
            state_in_sel  => state_in_sel,
            wrd2add_sel   => wrd2add_sel,
            data_size     => data_size,
            pad_key       => pad_key,
            extract       => extract,
            sel_decrypt   => sel_decrypt,
            perm_valid    => perm_valid,
            --! To ctrl
            tag_neq       => tag_neq,
            --! from pre-processor
            bdi0          => bdi(CCW - 1 downto 0),
            bdi1          => bdi(PDI_SHARES * CCW - 1 downto CCW),
            key0          => key(CCSW - 1 downto 0),
            key1          => key(SDI_SHARES * CCSW - 1 downto CCW),
            bdo0          => bdo(CCW - 1 downto 0),
            bdo1          => bdo(PDI_SHARES * CCW - 1 downto CCW),
            tag0          => cc_tag(CCW - 1 downto 0),
            tag1          => cc_tag(PDI_SHARES * CCW - 1 downto CCW),
            prng_rdi_data => rdi
        );

    ctrl : entity work.xoodyak_ctrl(behav)
        port map(
            clk             => clk,
            rst             => rst,
            --PreProcessor===============================================
            ----!key----------------------------------------------------
            key_valid       => key_valid,
            key_ready       => key_ready,
            ----!Data----------------------------------------------------
            bdi_valid       => bdi_valid,
            bdi_ready       => bdi_ready,
            bdi_pad_loc     => bdi_pad_loc,
            bdi_valid_bytes => bdi_valid_bytes,
            bdi_size        => bdi_size,
            bdi_eot         => bdi_eot,
            bdi_eoi         => bdi_eoi,
            bdi_type        => bdi_type,
            decrypt_in      => decrypt_in,
            key_update      => key_update,
            hash_in         => hash_in,
            --!Post Processor=========================================
            bdo_valid       => bdo_valid,
            bdo_ready       => bdo_ready,
            bdo_type        => bdo_type,
            bdo_valid_bytes => bdo_valid_bytes,
            end_of_block    => end_of_block,
            msg_auth_valid  => open,
            msg_auth_ready  => msg_auth_ready,
            msg_auth        => open,
            --! To datapath
            start_f         => start_f,
            f_ready         => f_ready,
            f_done          => f_done,
            init            => init,
            state_en        => state_en,
            cucd            => cucd,
            wrd_offset      => wrd_offset,
            offset_01       => offset_01,
            state_in_sel    => state_in_sel,
            wrd2add_sel     => wrd2add_sel,
            data_size       => data_size,
            pad_key         => pad_key,
            extract         => extract,
            sel_decrypt     => sel_decrypt,
            --! From datapath
            tag_neq         => tag_neq,
            perm_valid      => perm_valid,
            --! rdi data form outside world to be used as PRNG seed
            rdi_valid       => rdi_valid,
            rdi_ready       => rdi_ready,
            cc_tag_valid    => cc_tag_valid,
            cc_tag_ready    => cc_tag_ready,
            cc_tag_last     => cc_tag_last,
            tv_done         => msg_auth_valid and msg_auth_ready -- in
        );

    INST_TAG_VERIF : entity work.tag_verif
        port map(
            clk            => clk,
            rst            => rst,
            -- Tag received
            bdi            => bdi,
            bdi_type       => bdi_type,
            bdi_last       => bdi_eot,
            bdi_valid      => cc_tag_valid and bdi_valid,
            bdi_ready      => open,     -- don't need it
            -- CryptoCore
            cc_tag         => cc_tag,
            cc_tag_last    => cc_tag_last,
            cc_tag_valid   => cc_tag_valid,
            cc_tag_ready   => cc_tag_ready,
            --
            --
            rdi            => rdi(PDI_SHARES * CCW - 1 downto 0), -- TODO
            rdi_valid      => '1',      -- tv_rdi_valid,
            rdi_ready      => open,     --tv_rdi_ready,
            --
            msg_auth_valid => msg_auth_valid,
            msg_auth_ready => msg_auth_ready,
            msg_auth       => msg_auth
        );
        --    DEBUG_cc_tag <= cc_tag(CCW-1 downto 0) xor cc_tag(PDI_SHARES*CCW-1 downto CCW);
        --    DEBUG_expected_tag <= bdi(CCW-1 downto 0) xor bdi(PDI_SHARES*CCW-1 downto CCW);

end behavioral;
