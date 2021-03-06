--*********************************************************************
-- Block RAM, single-port, built with CORE Generator.
--*********************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity BRamSPCoreGen is
  port (
    clk_i : in  std_logic;
    sum_o : out std_logic_vector(31 downto 0) := (others => '0')
    );
end entity;

architecture Behavioral of BRamSPCoreGen is
  component BRAM
    port (
      clka  : in  std_logic;
      wea   : in  std_logic_vector(0 downto 0);
      addra : in  std_logic_vector(7 downto 0);
      dina  : in  std_logic_vector(7 downto 0);
      douta : out std_logic_vector(7 downto 0)
      );
  end component;
  constant NO          : std_logic := '0';
  constant YES         : std_logic := '1';
  constant RAM_SIZE_C  : natural   := 256;  -- Number of words in RAM.
  constant RAM_WIDTH_C : natural   := 8;   -- Width of RAM words.
  constant MIN_ADDR_C  : natural   := 1;   -- Process RAM from this address ...
  constant MAX_ADDR_C  : natural   := 5;   -- ... to this address.
  subtype RamWord_t is unsigned(RAM_WIDTH_C-1 downto 0);   -- RAM word type.
  signal wr_s          : std_logic;     -- Write-enable control.
  signal addr_r, prevAddr_r : natural range 0 to RAM_SIZE_C-1;  -- RAM address.
  signal dataToRam_r   : RamWord_t;     -- Data to write to RAM.
  signal dataFromRam_s : RamWord_t;     -- Data read from RAM.
  signal sum_r         : natural range 0 to RAM_SIZE_C * (2**RAM_WIDTH_C) - 1;
  signal addrCoreGen_s : std_logic_vector(7 downto 0);
  signal dataToRamCoreGen_s : std_logic_vector(7 downto 0);
  signal dataFromRamCoreGen_s : std_logic_vector(7 downto 0);
begin

  --*********************************************************************
  -- Instantiate the block RAM created by CORE Generator.
  --*********************************************************************
  ram_u0 : BRAM
    port map (
      clka   => clk_i,
      wea(0) => wr_s,
      addra  => addrCoreGen_s,
      dina   => dataToRamCoreGen_s,
      douta  => dataFromRamCoreGen_s
      );
      
  -- Connect the RAM signals to the signals from the FSM.     
  dataToRamCoreGen_s <= std_logic_vector(dataToRam_r);
  dataFromRam_s <= RamWord_t(dataFromRamCoreGen_s);
  addrCoreGen_s <= std_logic_vector(TO_UNSIGNED(addr_r,8));

  --*********************************************************************
  -- State machine that initializes RAM and then reads RAM to compute
  -- the sum of products of the RAM address and data.
  --*********************************************************************
  Fsm_p : process (clk_i)
    type state_t is (INIT, WRITE_DATA, READ_AND_SUM_DATA, DONE);
    variable state_v : state_t := INIT;    -- Start off in init state.
  begin
    if rising_edge(clk_i) then
      case state_v is
        when INIT =>
          wr_s        <= YES;           -- Enable writing of RAM.
          addr_r      <= MIN_ADDR_C;    -- Start writing data at this address.
          dataToRam_r <= TO_UNSIGNED(1, RAM_WIDTH_C);  -- Initial value to write.
          state_v     := WRITE_DATA;    -- Go to next state.
        when WRITE_DATA =>
          if addr_r < MAX_ADDR_C then   -- If haven't reach final address ...
            addr_r      <= addr_r + 1;  -- go to next address ...
            dataToRam_r <= dataToRam_r + 3;            -- and write this value.
          else  -- Else, the final address has been written...
            wr_s    <= NO;              -- so turn off writing, ...
            addr_r  <= MIN_ADDR_C;      -- go back to the start, ...
            sum_r   <= 0;               -- clear the sum-of-products, ...
            state_v := READ_AND_SUM_DATA;  -- and go to next state.
            prevAddr_r <= 0;            -- THIS IS A HACK!
          end if;
        when READ_AND_SUM_DATA =>
          if addr_r <= MAX_ADDR_C + 1 then  -- If not the final address+1 ...
            -- add product of previous RAM address and data read 
            -- from that address to the summation ...
            sum_r  <= sum_r + TO_INTEGER(dataFromRam_s * prevAddr_r);
            addr_r <= addr_r + 1;       -- and go to next address.
          else  -- Else, the final address has been read ...
            state_v := DONE;            -- so go to the next state.
          end if;
          prevAddr_r <= addr_r;         -- Store current address ...
        when DONE =>                    -- Summation complete ...
          null;                         -- so wait here and do nothing.
        when others =>                  -- Erroneous state ...
          state_v := INIT;              -- so re-run the entire process.
      end case;
    end if;
  end process;
  
  -- Output the sum of the RAM address-data products.
  sum_o <= std_logic_vector(TO_UNSIGNED(sum_r, sum_o'length));

end architecture;
