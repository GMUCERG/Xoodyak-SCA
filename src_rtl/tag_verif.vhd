--===============================================================================================--
--! @file       tag_verif.vhd
--! @brief      Secure TAG verification
--! @author     Kamyar Mohajerani
--! @copyright  Copyright (c) 2022 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--!
---------------------------------------------------------------------------------------------------
--!
--!
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

entity tag_verif is
   port(
      clk            : in  std_logic;
      rst            : in  std_logic;
      -- Tag received for verification
      bdi            : in  std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
      bdi_type       : in  std_logic_vector(4 - 1 downto 0);
      bdi_last       : in  std_logic;
      bdi_valid      : in  std_logic;
      bdi_ready      : out std_logic;
      -- CryptoCore's generated tag
      cc_tag         : in  std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
      cc_tag_last    : in  std_logic;
      cc_tag_valid   : in  std_logic;
      cc_tag_ready   : out std_logic;
      --
      -- TODO: is rdi really necessary?
      rdi            : in  std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
      rdi_valid      : in  std_logic;
      rdi_ready      : out std_logic;
      --
      msg_auth_valid : out std_logic;
      msg_auth_ready : in  std_logic;
      msg_auth       : out std_logic
   );

   attribute DONT_TOUCH of tag_verif : entity is "true";

end entity;

architecture RTL of tag_verif is
   type T_STATE is (S_INIT, S_INPUT, S_FIN, S_SEND_AUTH);
   -- registers
   signal state                 : T_STATE;
   signal shared_reg, mixed_reg : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
   signal failed                : std_logic;
   signal valids                : std_logic_vector(1 downto 0);

   -- wires
   signal type_ok, pipeline_go, failed_so_far : std_logic;

   attribute DONT_TOUCH of RTL : architecture is "true";
   attribute DONT_TOUCH of shared_reg : signal is "true";
   attribute DONT_TOUCH of mixed_reg : signal is "true";
begin

   -- not really needed
   type_ok <= '1' when bdi_type = HDR_TAG else '0';
   msg_auth <= not failed;

   -- We always (combinationally) mix corresponding shares of BDI and tag (BDO) outputs
   -- Different shares are not mixed though, so should be perfectly safe.

   process(all)
      variable tmp_mixed : std_logic_vector(CCW - 1 downto 0);
   begin
      tmp_mixed     := mixed_reg(CCW - 1 downto 0);
      for i in 1 to PDI_SHARES - 1 loop
         tmp_mixed := tmp_mixed xor mixed_reg((i + 1) * CCW - 1 downto i * CCW);
      end loop;
      failed_so_far <= (or tmp_mixed) or failed;
   end process;

   process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            state <= S_INIT;
         else
            if pipeline_go = '1' then
               if valids(0) = '1' then
                  mixed_reg <= shared_reg;
               end if;
               if valids(1) = '1' then
                  failed <= failed_so_far;
               end if;
            end if;

            case state is
               when S_INIT =>
                  failed <= '0';
                  valids <= (others => '0');
                  state  <= S_INPUT;

               when S_INPUT =>
                  -- wait for both bdi and cc_tag valid
                  if bdi_valid = '1' and bdi_ready = '1' then
                     valids     <= valids(valids'length - 2 downto 0) & '1';
                     --  not mixing shares
                     shared_reg <= bdi xor cc_tag;
                     if bdi_last = '1' or cc_tag_last = '1' then
                        state <= S_FIN;
                     end if;
                  end if;

               when S_FIN =>
                  valids <= valids(valids'length - 2 downto 0) & '0';
                  if valids(1) = '0' then
                     state <= S_SEND_AUTH;
                  end if;

               when S_SEND_AUTH =>      -- extra state
                  if msg_auth_ready = '1' then
                     -- report "Tag verified! Result: " & to_string(msg_auth);
                     state <= S_INIT;
                  end if;

            end case;
         end if;
      end if;
   end process;

   process(all)
   begin
      rdi_ready      <= '0';
      bdi_ready      <= '0';
      cc_tag_ready   <= '0';
      msg_auth_valid <= '0';
      pipeline_go    <= '0';

      case state is
         when S_INIT =>
            null;

         when S_INPUT =>
            -- wait until both bdi and cc_tag are valid
            bdi_ready    <= cc_tag_valid and type_ok;
            cc_tag_ready <= bdi_valid and type_ok;
            pipeline_go  <= bdi_valid and bdi_ready;

         when S_FIN =>
            pipeline_go <= '1';

         when S_SEND_AUTH =>
            msg_auth_valid <= '1';
            -- mixing of shares in only on the content of comp

      end case;
   end process;
end architecture;

