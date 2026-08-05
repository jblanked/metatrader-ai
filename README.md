# MetaTrader AI
An AI-powered trading assistant for MetaTrader 4 and MetaTrader 5! Now you can use AI in your trading strategies. Watch the video below for a quick overview of the features and capabilities of MetaTrader AI.

<a href="http://www.youtube.com/watch?feature=player_embedded&v=xGR-dZTS1P0" target="_blank">
 <img src="http://img.youtube.com/vi/xGR-dZTS1P0/default.jpg" alt="Watch the video" width="240" height="180" border="1" />
</a> 

## Features

| Feature | Python | MQL |
|---------|--------|-----|
| Open, close, modify positions & orders | ✅ | ✅ |
| Modify SL, TP, and entry prices | ✅ | ✅ |
| Fetch positions, orders, and deal history | ✅ | ✅ |
| Account info (balance, equity, margin, etc.) | ✅ | ✅ |
| Symbol info (bid, ask, spread, digits, lots) | ✅ | ✅ |
| OHLCV bars and individual bar prices | ✅ | ✅ |
| Pip value and risk-based lot sizing | ✅ | ✅ |
| MQL5 file compilation | ✅ | ✅ |
| 20+ technical indicators (MA, RSI, ATR, ADX, MACD, Stochastic, CCI, WPR, Momentum, Envelopes, Fractals, Bulls/Bears Power, VWAP, PVI, AO, ADR, ATHR, custom) | — | ✅ |
| Chart screenshots and analysis | — | ✅ |
| Open, close, and inspect charts | — | ✅ |
| Enable/disable symbols in Market Watch | — | ✅ |
| Terminal info (OS, CPU, memory, build, connection) | — | ✅ |
| File operations (read, write, copy, move, delete) | — | ✅ |
| Chat GUI (desktop or on-chart panel) | ✅ Desktop | ✅ On-chart |
| Backtesting (single test) | — | ✅ |
| Backtesting (optimization) | — | ✅ |
| Create expert advisors, indicators, and scripts | — | ✅ |

## Requirements
- Windows operating system (for Python integration, MQL works on all platforms that MetaTrader supports)
- MetaTrader 5 and Python 3.9.7 or higher for Python integration
- MetaTrader 4 or MetaTrader 5 for MQL integration
- OpenAI or DeepSeek API key

## Installation

### Python

```bash
pip install metatrader-ai
```

### MQL

> [!WARNING]
> If you are not a developer or just want to jump right in, copy the `app.ex5` file from the `mql` folder into your MetaTrader 5 `Experts` folder and run it from the Navigator panel inside of MetaTrader 5. The MQL source code is provided for developers who want to customize the agent or integrate it into their own expert advisors, indicators, or scripts. Read below for instructions on how to set up the MQL source code.

1. Navigate to MetaTrader's data folder (File → Open Data Folder), then:
```bash
cd "C:\Users\YourUsername\AppData\Roaming\MetaQuotes\Terminal\YourTerminalID"
cd MQL4 # or MQL5
cd Include
```
2. Clone the repo into the Includes folder:
```bash
git clone https://github.com/jblanked/metatrader-ai.git
```

## Usage

### Desktop GUI (Python)

```python
from metatrader_ai.app import launch
from metatrader_ai.llm import DEEPSEEK  # or OPENAI

launch(
    api_key="...",
    account_login=...,
    account_password="...",
    broker_server_name="...",
    model=DEEPSEEK,  # default; use OPENAI for OpenAI
)
```

Or pass a pre-built agent:

```python
from metatrader_ai.app import launch
from metatrader_ai.agent import Agent

agent = Agent(
    api_key="...",
    account_login=...,
    account_password="...",
    broker_server_name="...",
)
launch(agent=agent)
```

Without an agent (info-only mode):

```python
from metatrader_ai.app import launch
launch()
```

The Chat tab lets you converse with the AI assistant about your positions, market analysis, and trading strategies. The Info tab displays terminal, symbol, and account details from MetaTrader 5.

### One-shot Function

```python
from metatrader_ai.agent import run

result = run(
      api_key=API_KEY,
      account_login=ACCOUNT_LOGIN,
      account_password=ACCOUNT_PASS,
      broker_server_name=BROKER_NAME,
      prompt="What is the daily high of ETHUSD?",
)
```

### Multi-turn Class API

```python
from metatrader_ai.agent import Agent

agent = Agent(
    api_key="...",
    account_login=...,
    account_password="...",
    broker_server_name="...",
)
response = agent.run("What is the daily high of ETHUSD?")
print(response)
```

### Command Line

```bash
metatrader-ai \
   --api-key "$DEEPSEEK_API_KEY" \
   --account-login "$ACCOUNT_LOGIN" \
   --account-pass "$ACCOUNT_PASS" \
   --broker-name "$BROKER_NAME" \
   --provider deepseek
```

Use `--provider openai` (with `OPENAI_API_KEY`) to switch to OpenAI.

Single prompt mode:

```bash
metatrader-ai --prompt "Show account info" ...
```

### MQL (In-Editor)

```c++
#include <metatrader-ai/mql/agent.mqh>

void OnStart()
{
   Agent *agent = new Agent(
      "your-api-key",               // API key
      LLM_PROVIDER_DEEPSEEK,        // provider (default)
      LLM_MODEL_DEEPSEEK_V4_FLASH   // model (default)
   );
   string response = agent.run("What is the daily high of ETHUSD?");
   Print("[Agent] ", response);
   delete agent;
}
```

Use `LLM_PROVIDER_OPENAI` with an OpenAI model (e.g. `OPENAI_MODEL_GPT_5_4_MINI`) to switch providers.

Or compile and run `app.mq5` (in `metatrader-ai/mql`) to get an on-chart chat panel with provider/model inputs where you can type prompts and see AI responses.


## Notes
-  I am available for hire to integrate your strategy into the system, with advanced prompts and multi layer thinking: https://www.jblanked.com/coding-request/
- In the Python environment, two LLM providers are supported: DeepSeek (`deepseek-v4-flash`, default) and OpenAI (`gpt-5.4-mini`). Switch with `--provider` in the CLI or `model=OPENAI` / `model=DEEPSEEK` (from `metatrader_ai.llm`) in code. In MQL, switch providers and models with the `providerId` and `providerModel` parameters when creating the Agent (e.g. `LLM_PROVIDER_OPENAI` with `OPENAI_MODEL_GPT_5_4_MINI`).
- The python environment works best directly inside of MetaTrader5, but if you run it from a Windows terminal, you should open up MetaTrader5 and log in to your account first, then run the python script for the best experience. The script attempts to open and login to MetaTrader5 if it is not already open.

## Disclaimer
Trading and investing involve substantial risk. Past performance is not indicative of future results. This software is provided for educational and informational purposes only and should not be considered as financial advice. Always do your own research and consult with a qualified financial advisor before making any trading decisions. JBlanked and the developers of this software are not responsible for any losses or damages that may occur from using this software.