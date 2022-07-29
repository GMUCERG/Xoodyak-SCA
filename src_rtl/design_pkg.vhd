--------------------------------------------------------------------------------
--! @file       Design_pkg.vhd
--! @brief      Package for the Cipher Core.
--!
--! @author     Michael Tempelmeier <michael.tempelmeier@tum.de>
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.sca_gadgets_pkg.all;

package design_pkg is
    constant NUM_TRIVIUM_UNITS : integer := 6; --! Trivium instances used in PRNG
    constant SEED_SIZE         : integer := NUM_TRIVIUM_UNITS * 128;
    constant SCA_GADGET        : string  := "HPC3+"; -- "HPC3", "HPC3+", or "DOM"; 
    --    constant  
    --------------------------------------------------------------------------------
    --------------------------- DO NOT CHANGE ANYTHING BELOW -------------------------
    ----------------------------------------------------------------------------------
    --    --! design parameters needed by the Pre- and Postprocessor
    constant TAG_SIZE          : integer := 128; --! Tag size
    constant HASH_VALUE_SIZE   : integer := 128; --! Hash value size

    constant CCSW    : integer  := 32;  --! variant dependent design parameters are assigned in body!
    constant CCW     : integer  := 32;  --! variant dependent design parameters are assigned in body!
    constant CCWdiv8 : integer  := 32 / 8; --! derived from parameters above, assigned in body.
    constant CCRW    : positive := num_rand_bits(SCA_GADGET, 384, 1); --! variant dependent design parameters are assigned in body!

    attribute DONT_TOUCH : string;

end design_pkg;
