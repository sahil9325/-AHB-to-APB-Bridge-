# Design and UVM-Based Verification of an AHB-to-APB Bridge using SystemVerilog

## 📌 Project Overview

This project implements an **AMBA AHB-to-APB Bridge** using **SystemVerilog RTL** along with a complete **UVM-based verification environment**.  
The bridge connects a high-speed **AHB bus** to a low-speed **APB peripheral bus** and interfaces with an **APB SRAM peripheral**.

The project demonstrates:
- RTL Design
- Finite State Machine (FSM) based protocol conversion
- APB SRAM peripheral implementation
- UVM Verification Methodology
- Functional Coverage
- Scoreboarding
- Constrained Random Verification

---

# 📖 Introduction

Modern SoCs use multiple bus protocols to communicate between processors and peripherals.

- **AHB (Advanced High-performance Bus)** is used for:
  - High-speed communication
  - Pipelined transfers
  - Processor and memory interfaces

- **APB (Advanced Peripheral Bus)** is used for:
  - Low-power peripherals
  - Simple register-based communication
  - UART, GPIO, Timers, SRAM, etc.

Since AHB and APB operate differently, a **bridge** is required to convert AHB transactions into APB transactions.

This project designs and verifies such a bridge using industry-standard methodologies.

---

# 🎯 Objectives

- Design synthesizable RTL for an AHB-to-APB bridge
- Implement APB SRAM as peripheral memory
- Develop FSM-based transfer control
- Verify the design using UVM
- Achieve functional coverage
- Validate read/write transactions
- Implement scoreboard-based checking

---

# 🏗️ System Architecture

```text
          +------------------+
          |    AHB Master    |
          +------------------+
                    |
                    v
          +------------------+
          | AHB-APB Bridge   |
          +------------------+
                    |
                    v
          +------------------+
          |    APB SRAM      |
          +------------------+
```

---

# ⚙️ Features

## RTL Design Features
- AHB Slave Interface
- APB Master Interface
- FSM-Based Protocol Conversion
- Address and Data Sampling
- Read and Write Support
- Burst Transfer Support
- Error Handling Support
- Synthesizable SystemVerilog RTL

---

## Verification Features
- UVM Testbench Architecture
- Driver
- Monitor
- Sequencer
- Agent
- Environment
- Scoreboard
- Functional Coverage
- Constrained Random Testing
- Multiple UVM Test Cases

---

# 🧠 FSM Working

The bridge uses a **3-state FSM**:

| State | Description |
|------|-------------|
| IDLE | Waiting for AHB transfer |
| SETUP | APB setup phase |
| ACCESS / ENABLE | APB transfer execution |

---

## FSM Transition

```text
IDLE --> SETUP --> ENABLE --> IDLE
```

---

# 🧩 APB SRAM Peripheral

The APB peripheral used in this project is an SRAM memory block.

### SRAM Specifications
- 256 memory locations
- 32-bit data width
- APB-controlled read/write
- Word-aligned addressing

---

# 🔄 Working Principle

## WRITE Operation
1. AHB master sends address and data
2. Bridge captures AHB signals
3. FSM moves from IDLE → SETUP
4. APB signals generated
5. SRAM stores incoming data

---

## READ Operation
1. AHB master sends read request
2. Bridge generates APB read cycle
3. SRAM returns data
4. Bridge forwards data to AHB side

---

# 🛠️ Tools & Technologies

| Tool | Purpose |
|------|---------|
| Vivado 2025.2 | RTL Design & Synthesis |
| SystemVerilog | RTL Design |
| UVM | Verification Methodology |
| QuestaSim / Xcelium / VCS | UVM Simulation |
| GitHub | Version Control |

---

# 📂 Project Structure

```text
├── rtl/
│   ├── ahb_apb_bridge.sv
│   ├── apb_sram.sv
│
├── tb/
│   ├── tb_top.sv
│   ├── interfaces/
│   ├── agents/
│   ├── sequences/
│   ├── tests/
│   ├── scoreboard/
│
├── docs/
│
├── README.md
```

---

# 🧪 Verification Methodology

The project uses **UVM (Universal Verification Methodology)**.

### Verification Components
- AHB Driver
- AHB Monitor
- APB Monitor
- Sequencer
- Agent
- Environment
- Scoreboard
- Coverage Collector

---

# 📊 Functional Coverage

Coverage is collected for:
- Read operations
- Write operations
- Burst transactions
- Transfer types
- Error scenarios
- APB responses

---

# ✅ Implemented Test Cases

| Test Case | Description |
|----------|-------------|
| RW Test | Random read/write operations |
| WR-RD Test | Write followed by readback |
| Burst Test | Consecutive burst writes |
| Error Test | Invalid/out-of-range address testing |

---

# 🚀 Simulation

## Vivado RTL Simulation
- Behavioral Simulation
- Waveform Analysis
- FSM Verification

---

## UVM Simulation

### QuestaSim
```bash
vsim -c -do "run -all" work.tb_top
```

### Xcelium
```bash
xrun -sv -uvm ahb_apb_bridge_uvm_complete.sv +UVM_TESTNAME=rw_test
```

---

# 📈 Synthesis

The RTL design is fully synthesizable and successfully synthesized using Vivado.

### Synthesized Components
- FSM Logic
- Registers
- Address Decoder
- SRAM Memory Logic
- APB Control Logic

---

# 📸 Results

## Achievements
- Successful AHB to APB protocol conversion
- Correct SRAM read/write operation
- Successful synthesis
- Verified functionality using UVM
- Functional coverage achieved

---

# 🎓 Learning Outcomes

Through this project, the following concepts were learned:

- AMBA Bus Protocols
- AHB Protocol
- APB Protocol
- FSM Design
- RTL Coding
- SystemVerilog
- UVM Verification
- Functional Coverage
- Assertions
- Synthesis Flow
- Waveform Debugging

---

# 💡 Future Enhancements

- AXI to APB Bridge
- Multi-slave APB support
- APB4 protocol support
- Advanced burst handling
- Formal verification
- FPGA implementation

---

# 👨‍💻 Author

**Sahil Jangra**  
Electronics and Communication Engineering (ECE)

---

# 📜 License

This project is developed for academic and educational purposes.

---

# ⭐ GitHub Repository

If you found this project useful, consider giving it a ⭐ on GitHub.

---

# 📎 Reference

AMBA Protocol Specification by ARM

---

# 🔥 Project Highlights

✅ RTL Design  
✅ UVM Verification  
✅ Functional Coverage  
✅ Scoreboard Validation  
✅ SRAM Peripheral  
✅ Synthesizable Design  
✅ Vivado Compatible  
✅ Industry-Oriented Project  
