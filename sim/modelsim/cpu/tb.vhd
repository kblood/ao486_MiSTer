library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;
use ieee.math_real.all;      

use work.globals.all;

entity etb  is
end entity;

architecture arch of etb is

   signal clk   : std_logic := '1';
   signal rst_n : std_logic := '0';
   signal rst   : std_logic := '0';
   
   signal avm_address       : std_logic_vector(29 downto 0);
   signal avm_writedata     : std_logic_vector(31 downto 0);
   signal avm_byteenable    : std_logic_vector(3 downto 0);
   signal avm_burstcount    : std_logic_vector(3 downto 0);
   signal avm_write         : std_logic;
   signal avm_read          : std_logic;
   signal avm_read_64       : std_logic;
                           
   signal avm_waitrequest   : std_logic := '0';
   signal avm_readdatavalid : std_logic := '0';
   signal avm_readdata      : std_logic_vector(31 downto 0);
   signal avm_readdata_64   : std_logic_vector(63 downto 0);
   
   signal DDRAM_OUT_BUSY       : std_logic := '0'; 
   signal DDRAM_OUT_DOUT       : std_logic_vector(63 downto 0); 
   signal DDRAM_OUT_DOUT_READY : std_logic; 
   signal DDRAM_OUT_BURSTCNT   : std_logic_vector(7 downto 0); 
   signal DDRAM_OUT_ADDR       : std_logic_vector(27 downto 0) := (others => '0'); 
   signal DDRAM_OUT_RD         : std_logic; 
   signal DDRAM_OUT_DIN        : std_logic_vector(63 downto 0);
   signal DDRAM_OUT_BE         : std_logic_vector(7 downto 0);
   signal DDRAM_OUT_WE         : std_logic; 
    
   signal DDRAM_IN_BUSY        : std_logic; 
   signal DDRAM_IN_DOUT        : std_logic_vector(31 downto 0); 
   signal DDRAM_IN_DOUT_64     : std_logic_vector(63 downto 0); 
   signal DDRAM_IN_DOUT_READY  : std_logic; 
   signal DDRAM_IN_BURSTCNT    : std_logic_vector(3 downto 0); 
   signal DDRAM_IN_ADDR        : std_logic_vector(31 downto 0); 
   signal DDRAM_IN_RD          : std_logic; 
   signal DDRAM_IN_RD_64       : std_logic; 
   signal DDRAM_IN_DIN         : std_logic_vector(31 downto 0) := (others => '0');
   signal DDRAM_IN_BE          : std_logic_vector(3 downto 0);
   signal DDRAM_IN_WE          : std_logic;
  
   signal mgmt_address         : std_logic_vector(7 downto 0);
   signal mgmt_write           : std_logic;
   signal mgmt_writedata       : std_logic_vector(31 downto 0);
  
   type t_data is array(0 to (2**27)-1) of integer;
   type bit_vector_file is file of bit_vector;
   
   signal tx_command  : std_logic_vector(31 downto 0);
   signal tx_bytes    : integer range 0 to 4;
   signal tx_enable   : std_logic := '0';
   
   signal cpuopt_enable : std_logic := '0';

   -- iter-248: interrupt-injection harness (Quake fmul->faddp retire-RAW probe).
   -- Inert for every existing test: write.v only takes an external IRQ at an
   -- instruction boundary when IF=1, and no other smoke test executes `sti`, so
   -- irq_do toggling here is never acted upon unless a test opts in.
   signal irq_do   : std_logic := '0';
   signal irq_vec  : std_logic_vector(7 downto 0) := x"FC";
   signal irq_done : std_logic;

   -- iter-271: opt-in CPU-side memory-latency injector (Quake fmul->faddp retire-
   -- window probe).  inj_en is raised by a guest write of a NONZERO value to byte
   -- address 0xE10 (see the memory write handler); default '0' keeps inj_busy de-
   -- asserted so avm_waitrequest is unchanged and EVERY EXISTING TEST IS UNAFFECTED.
   -- When enabled, each new CPU access is held off (avm_waitrequest) for a free-
   -- running 0..8 cycle count that advances per access, jittering the back-to-back
   -- FMUL->FADDP retire window the way variable L2/DDR latency does on silicon
   -- (operands are L2-cached, so injection MUST be CPU-side, not at DDRAM_OUT).
   signal inj_en   : std_logic := '0';
   signal inj_busy : std_logic := '0';


begin

   clk   <= not clk after 5 ns;
   rst   <= not rst_n;

   -- iter 83: sim-time watchdog (REVISED iter 86 after iter-85 measurement).
   -- The existing sentinel-write exit at DDRAM_OUT_WE (0xCAFEBABE@0x1F0)
   -- only fires on CLEAN smoke completion.  Any uncaught #MF / spurious
   -- exception / hung op silently spins the sim in the listing's
   -- `jmp infinite_loop` tail with no termination signal — iter 78 ran
   -- 4h, iter 82 ran 8.5h, iter 85 ran ~10 min before external kill.
   -- 5 ms sim-time at 100 MHz = 500k cycles.  A clean smoke finishes in
   -- well under 1 ms sim-time (iter 80 PR-2b.4k FLD smoke = 16170 ns;
   -- iter 82 reached TEST 7 at ~600us; iter 84 isolation = 15240 ns).
   -- ITER-85 MEASUREMENT: ~1.67 us sim-time per sec wall-clock for AO486
   -- cpu/ TB with FPU + L2 + cpu_export.  100 ms sim-time = ~16.7 hours
   -- wall-clock — useless as a wall-clock cap.  5 ms sim-time ≈ 50 min
   -- wall-clock — useful cap with 5x headroom over even iter-82's full
   -- 8-test trap-spin.  See [[feedback-watchdog-simtime-vs-walltime]].
   process
   begin
      wait for 4 ms;   -- iter-248: raised 1->4 ms so multi-iteration IRQ-sweep tests can complete
      assert false
         report "iter-86 sim-time watchdog: 4 ms elapsed without smoke sentinel; likely #MF, hung op, or infinite_loop without 0xCAFEBABE@0x1F0 commit"
         severity failure;
   end process;

   process
      variable idlecnt  : integer := 0;
   begin
      wait until rising_edge(clk);
      if (tx_enable = '1') then
         rst_n         <= not tx_command(0);
         cpuopt_enable <= tx_command(1);
         wait until rising_edge(clk);
         wait until rising_edge(clk);
      end if;
   end process;
   
   --process
   --   variable seed1, seed2 : integer := 999;
   --   variable r : real;
   --   variable cnt : integer;
   --begin
   --
   --   uniform(seed1, seed2, r);
   --   cnt := 1 + integer(round(r * 20.0));
   --   for i in 1 to cnt loop
   --      wait until rising_edge(clk);
   --   end loop;
   --   DDRAM_OUT_BUSY <= not DDRAM_OUT_BUSY;
   --
   --end process;
   

   -- iter-248 interrupt-injection: periodically RAISE an external IRQ so the
   -- core takes it at an instruction boundary (write.v gates on IF + boundary).
   -- Held until interrupt_done acks, then dropped; re-raised on a prime period
   -- (53) so the in-loop phase drifts across the fmul->faddp retire window over
   -- many outer-loop iterations.  The guest sets IVT[0xFC]->iret stub and `sti`
   -- before the loop; the IF gate makes an early raise harmless.
   irq_inject : process(clk)
      variable cnt : integer := 0;
   begin
      if rising_edge(clk) then
         if rst_n = '0' then
            irq_do <= '0';
            cnt    := 0;
         else
            cnt := cnt + 1;
            if irq_done = '1' then
               irq_do <= '0';
            elsif (cnt mod 1009) = 0 then  -- >> interrupt service time so the
               irq_do <= '1';              -- main FPU loop progresses between IRQs
            end if;
         end if;
      end if;
   end process;

   -- iter-271: per-access memory-latency jitter on the CPU-facing avm_waitrequest.
   -- Free-running phase advances 0->8->0 once per CPU access; each access is stalled
   -- 'phase' clocks before the real L2 busy is honoured.  Gated by inj_en (default 0),
   -- so de-asserted for EVERY test that does not enable it -> shared TB stays inert.
   inj_proc : process(clk)
      variable cnt   : integer := 0;     -- remaining stall clocks for the current access
      variable phase : integer := 0;     -- next stall length, cycles 0..8 per access
      variable busyv : std_logic := '0';
   begin
      if rising_edge(clk) then
         if rst_n = '0' then
            inj_busy <= '0'; cnt := 0; phase := 0; busyv := '0';
         elsif inj_en = '1' then
            if (avm_read = '1' or avm_write = '1') then
               if busyv = '0' and cnt = 0 then
                  -- start of a new access: load the next jitter length, advance phase
                  cnt   := phase;
                  phase := (phase + 1) mod 9;
                  busyv := '1';
               end if;
               if cnt > 0 then
                  inj_busy <= '1';
                  cnt := cnt - 1;
               else
                  inj_busy <= '0';       -- stall satisfied; command goes through
               end if;
            else
               busyv := '0';             -- request dropped: arm for the next access
               inj_busy <= '0';
            end if;
         else
            inj_busy <= '0';
         end if;
      end if;
   end process;

   iao486 : entity work.ao486
   port map
   (
      clk                        => clk,
      rst_n                      => rst_n,

	   a20_enable                 => '1',
      cache_disable              => '0',

      interrupt_do               => irq_do,
      interrupt_vector           => irq_vec,
      interrupt_done             => irq_done,
      
      avm_address                => avm_address      ,
      avm_writedata              => avm_writedata    ,
      avm_byteenable             => avm_byteenable   ,
      avm_burstcount             => avm_burstcount   ,
      avm_write                  => avm_write        ,
      avm_read                   => avm_read         ,
                                                     
      avm_waitrequest            => avm_waitrequest  ,
      avm_readdatavalid          => avm_readdatavalid,
      avm_readdata               => avm_readdata     ,
      
      dma_address                => (23 downto 0 => '0'),
      dma_writedata              => (15 downto 0 => '0'),
      dma_write                  => '0',
      dma_read                   => '0',
      dma_16bit                  => '0',
      
      io_read_data               => (31 downto 0 => '0'),
      io_read_done               => '1',
      io_write_done              => '1'
   );
   
   DDRAM_IN_BURSTCNT <= avm_burstcount;
   DDRAM_IN_ADDR     <= avm_address(29 downto 0) & "00";
   DDRAM_IN_RD       <= avm_read  and not inj_busy;  -- iter-271: hold cmd off L2 during stall
   DDRAM_IN_DIN      <= avm_writedata;
   DDRAM_IN_BE       <= avm_byteenable;
   DDRAM_IN_WE       <= avm_write and not inj_busy;  -- so L2 can't accept/return early

   avm_waitrequest   <= DDRAM_IN_BUSY or inj_busy;  -- iter-271: inj_busy=0 unless enabled
   avm_readdatavalid <= DDRAM_IN_DOUT_READY;
   avm_readdata      <= DDRAM_IN_DOUT;
   
   
   il2_cache : entity work.l2_cache
   port map
   (
      CLK                  => clk,
      RESET                => rst,
      
      DISABLE              => '0',
      uma_ram              => '0',

      DDRAM_ADDR           => DDRAM_OUT_ADDR(27 downto 3)      ,
      DDRAM_DIN            => DDRAM_OUT_DIN       ,
      DDRAM_DOUT           => DDRAM_OUT_DOUT ,
      DDRAM_DOUT_READY     => DDRAM_OUT_DOUT_READY   ,
      DDRAM_BE             => DDRAM_OUT_BE      ,
      DDRAM_BURSTCNT       => DDRAM_OUT_BURSTCNT         ,
      DDRAM_BUSY           => DDRAM_OUT_BUSY        ,
      DDRAM_RD             => DDRAM_OUT_RD         ,
      DDRAM_WE             => DDRAM_OUT_WE        ,
                                                  
      CPU_ADDR             => DDRAM_IN_ADDR(31 downto 2)       ,
      CPU_DIN              => DDRAM_IN_DIN        ,
      CPU_DOUT             => DDRAM_IN_DOUT  ,
      CPU_DOUT_READY       => DDRAM_IN_DOUT_READY    ,
      CPU_BE               => DDRAM_IN_BE        ,
      CPU_BURSTCNT         => DDRAM_IN_BURSTCNT          ,
      CPU_BUSY             => DDRAM_IN_BUSY         ,
      CPU_RD               => DDRAM_IN_RD          ,
      CPU_WE               => DDRAM_IN_WE        ,
      
      VGA_DIN              => (7 downto 0 => '0'),
      VGA_MODE             => "000",
      VGA_WR_SEG           => (5 downto 0 => '0'),
      VGA_RD_SEG           => (5 downto 0 => '0'),
      VGA_FB_EN            => '0'
   );
   
   
   iestringprocessor : entity work.estringprocessor
   port map
   (
      ready       => '1',
      tx_command  => tx_command,
      tx_bytes    => tx_bytes,  
      tx_enable   => tx_enable, 
      rx_command  => x"00000000",
      rx_valid    => '1'
   );
    
   process
      variable address : integer;
      
      variable data : t_data := (others => 0);
      
      variable readmodifywrite : std_logic_vector(31 downto 0);
      
      file infile             : bit_vector_file;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte0     : std_logic_vector(7 downto 0);
      variable read_byte1     : std_logic_vector(7 downto 0);
      variable read_byte2     : std_logic_vector(7 downto 0);
      variable read_byte3     : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (3 downto 0);
      variable actual_len     : natural;
      variable targetpos      : integer;
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
   
         temp := ARG;
         for i in 0 to SIZE-1 loop
   
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
   
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
   
        return result;  
      end;
      
   begin

      --file_open(f_status, infile, "boot0.rom", read_mode);
      --targetpos := 16#F0000# / 4;
      --while (not endfile(infile)) loop
      --   
      --   read(infile, next_vector, actual_len);  
      --    
      --   read_byte0 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
      --   read_byte1 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(1)), 8);
      --   read_byte2 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(2)), 8);
      --   read_byte3 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(3)), 8);
      --
      --   if (1 = 0) then -- endianswitch
      --      data(targetpos) := to_integer(signed(read_byte3 & read_byte2 & read_byte1 & read_byte0));
      --   else
      --      data(targetpos) := to_integer(signed(read_byte0 & read_byte1 & read_byte2 & read_byte3));
      --   end if;
      --   targetpos       := targetpos + 1;
      --end loop;
      --file_close(infile);
      --assert false report "boot0.rom loaded" severity note;
      --
      --file_open(f_status, infile, "mov.rom", read_mode);
      --targetpos := 0;
      --while (not endfile(infile)) loop
      --   
      --   read(infile, next_vector, actual_len);  
      --    
      --   read_byte0 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
      --   read_byte1 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(1)), 8);
      --   read_byte2 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(2)), 8);
      --   read_byte3 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(3)), 8);
      --
      --   if (1 = 0) then -- endianswitch
      --      data(targetpos) := to_integer(signed(read_byte3 & read_byte2 & read_byte1 & read_byte0));
      --   else
      --      data(targetpos) := to_integer(signed(read_byte0 & read_byte1 & read_byte2 & read_byte3));
      --   end if;
      --   targetpos       := targetpos + 1;
      --end loop;
      --file_close(infile);
      --assert false report "mov.rom loaded" severity note;
   
   
      DDRAM_OUT_DOUT_READY <= '0';
   
      while (0 = 0) loop
      
         -- data from file
         COMMAND_FILE_ACK <= '0';
         if COMMAND_FILE_START = '1' then
            
            assert false report "received" severity note;
            assert false report COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN) severity note;
         
            file_open(f_status, infile, COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN), read_mode);
         
            targetpos := COMMAND_FILE_TARGET  / 4;
         
            while (not endfile(infile)) loop
               
               read(infile, next_vector, actual_len);  
               
               read_byte0 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
               read_byte1 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(1)), 8);
               read_byte2 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(2)), 8);
               read_byte3 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(3)), 8);
            
               if (COMMAND_FILE_ENDIAN = '1') then
                  data(targetpos) := to_integer(signed(read_byte3 & read_byte2 & read_byte1 & read_byte0));
               else
                  data(targetpos) := to_integer(signed(read_byte0 & read_byte1 & read_byte2 & read_byte3));
               end if;
               targetpos       := targetpos + 1;
               
            end loop;
         
            file_close(infile);
         
            COMMAND_FILE_ACK <= '1';
         
         end if;
      
         if (DDRAM_OUT_BUSY = '0') then
            if (DDRAM_OUT_RD = '1') then
               address := to_integer(unsigned(DDRAM_OUT_ADDR)) / 4;
               for i in 1 to to_integer(unsigned(DDRAM_OUT_BURSTCNT)) loop
                  DDRAM_OUT_DOUT_READY <= '1';
                  DDRAM_OUT_DOUT <= std_logic_vector(to_signed(data(address + 1), 32)) &
                                    std_logic_vector(to_signed(data(address + 0), 32));
                  wait until rising_edge(clk);
                  address := address + 2;
               end loop;
               DDRAM_OUT_DOUT_READY <= '0';
            end if;
            
            if (DDRAM_OUT_WE = '1') then
               address := to_integer(unsigned(DDRAM_OUT_ADDR)) / 4;
               -- Byte-enabled write: read-modify-write each 32-bit half so
               -- BE-disabled bytes retain their prior value.  DDRAM_OUT_BE
               -- maps one bit per byte of the 64-bit DDRAM_OUT_DIN.
               readmodifywrite := std_logic_vector(to_signed(data(address + 0), 32));
               if DDRAM_OUT_BE(0) = '1' then readmodifywrite(7  downto  0) := DDRAM_OUT_DIN( 7 downto  0); end if;
               if DDRAM_OUT_BE(1) = '1' then readmodifywrite(15 downto  8) := DDRAM_OUT_DIN(15 downto  8); end if;
               if DDRAM_OUT_BE(2) = '1' then readmodifywrite(23 downto 16) := DDRAM_OUT_DIN(23 downto 16); end if;
               if DDRAM_OUT_BE(3) = '1' then readmodifywrite(31 downto 24) := DDRAM_OUT_DIN(31 downto 24); end if;
               data(address + 0) := to_integer(signed(readmodifywrite));
               readmodifywrite := std_logic_vector(to_signed(data(address + 1), 32));
               if DDRAM_OUT_BE(4) = '1' then readmodifywrite(7  downto  0) := DDRAM_OUT_DIN(39 downto 32); end if;
               if DDRAM_OUT_BE(5) = '1' then readmodifywrite(15 downto  8) := DDRAM_OUT_DIN(47 downto 40); end if;
               if DDRAM_OUT_BE(6) = '1' then readmodifywrite(23 downto 16) := DDRAM_OUT_DIN(55 downto 48); end if;
               if DDRAM_OUT_BE(7) = '1' then readmodifywrite(31 downto 24) := DDRAM_OUT_DIN(63 downto 56); end if;
               data(address + 1) := to_integer(signed(readmodifywrite));
               -- PR-2b.4k iter 80: smoke auto-terminate sentinel.  Any 32-bit
               -- write of 0xCAFEBABE to byte address 0x1F0 (chosen outside
               -- the existing smoke result buffer 0x100-0x10F and source
               -- data buffer 0x120-0x137; also <0xFFFF per
               -- feedback_smoke_listings_real_mode_segment_ivt) signals
               -- "all tests complete" and triggers a clean exit, capping
               -- vsim wall-clock at the actual smoke duration rather than
               -- letting it spin in the listing's infinite_loop tail
               -- forever (4 hours in iter 78).  The address+magic combo
               -- is specific enough that an accidental match is negligible.
               if (unsigned(DDRAM_OUT_ADDR) = to_unsigned(16#1F0#, 28)) and
                  (DDRAM_OUT_BE(3 downto 0) = "1111") and
                  (DDRAM_OUT_DIN(31 downto 0) = X"CAFEBABE") then
                  assert false report "PR-2b.4k smoke sentinel 0xCAFEBABE@0x1F0 detected; clean exit" severity failure;
               end if;
               -- iter-271: guest 32-bit write to byte addr 0xE10 toggles the memory-
               -- latency jitter injector.  Nonzero => enable (inj_en='1'); zero =>
               -- disable.  Inert for every test that never writes 0xE10.
               if (unsigned(DDRAM_OUT_ADDR) = to_unsigned(16#E10#, 28)) and
                  (DDRAM_OUT_BE(3 downto 0) = "1111") then
                  if (DDRAM_OUT_DIN(31 downto 0) = X"00000000") then
                     inj_en <= '0';
                  else
                     inj_en <= '1';
                  end if;
               end if;
            end if;
         end if;
         
         wait until rising_edge(clk);
      end loop;
   
   end process;
   
   
   
end architecture;


