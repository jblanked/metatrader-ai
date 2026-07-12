import json
from pathlib import Path
from typing import Optional

import requests

from .tools import dispatch, mt5
from .llm import DEEPSEEK, LLM, LOCAL

BASE_DIR = Path(__file__).resolve().parent

CONTEXT_FILES = [
    "context/python.md",
    "context/trade.md",
    "workflows/response.md",
]


class Agent:
    """Stateful MetaTrader AI agent that keeps multi-turn chat history."""

    def __init__(
        self,
        account_login: int,
        account_password: str,
        broker_server_name: str,
        api_key: str,
        model: int = DEEPSEEK,
    ):
        if (not api_key or len(api_key) < 3) and model != LOCAL:
            raise ValueError("No API key set.")
        
        self.llm = LLM( model)
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

        self.metatrader_client = mt5.MT5(
            account_login,
            account_password,
            broker_server_name,
        )
        dispatch.set_metatrader(self.metatrader_client)

        if not self.metatrader_client.login():
            raise RuntimeError(
                "Failed to connect to MetaTrader. Please check your credentials and connection."
            )

        self.messages = self.initialize_messages()

    @staticmethod
    def _read_markdown(relative_path: str) -> str:
        file_path = BASE_DIR / relative_path
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()

    def get_prompt(self) -> str:
        """Return the system prompt from package context files."""
        return self._read_markdown("context/prompt.md")

    def load_markdown_files(self, file_paths: list[str]) -> str:
        """Read markdown files from package data and combine their content."""
        combined = ""
        for rel_path in file_paths:
            combined += f"\n\n--- {rel_path} ---\n{self._read_markdown(rel_path)}"
        return combined

    def initialize_messages(self) -> list[dict]:
        """Build initial system context for a multi-turn conversation."""
        system_content = self.get_prompt() + self.load_markdown_files(CONTEXT_FILES)
        return [{"role": "system", "content": system_content}]

    def run(self, prompt: str) -> str:
        """Process one user turn and return the assistant response."""
        if not prompt:
            return ""

        self.messages.append({"role": "user", "content": prompt})
        tools = dispatch.get_tool_list()

        try:
            while True:
                payload: dict = {
                    "model": self.llm.model,
                    "messages": self.messages,
                    "tools": tools,
                    "tool_choice": "auto",
                }

                response = requests.post(
                    self.llm.url, headers=self.headers, json=payload, timeout=60
                )

                if not response.ok:
                    try:
                        detail = response.json()
                    except ValueError:
                        detail = response.text
                    return f"API error {response.status_code}: {detail}"

                data = response.json()
                message = data["choices"][0]["message"]

                if not message.get("tool_calls"):
                    assistant_content = message.get("content") or ""
                    self.messages.append(
                        {"role": "assistant", "content": assistant_content}
                    )
                    return assistant_content

                assistant_msg: dict = {
                    "role": "assistant",
                    "tool_calls": message["tool_calls"],
                }
                if message.get("content") is not None:
                    assistant_msg["content"] = message["content"]
                self.messages.append(assistant_msg)

                for tool_call in message["tool_calls"]:
                    name = tool_call["function"]["name"]
                    raw_args = tool_call["function"].get("arguments") or "{}"

                    try:
                        args = json.loads(raw_args)
                    except json.JSONDecodeError:
                        args = {}

                    result = dispatch.execute_tool(name, args)

                    self.messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": tool_call["id"],
                            "content": str(result),
                        }
                    )
        except (
            requests.RequestException,
            RuntimeError,
            ValueError,
            TypeError,
            KeyError,
        ) as e:
            return f"An error occurred during processing: {e}"

    def chat(self) -> None:
        """Run the interactive terminal chat loop."""
        while True:
            prompt = input("\033[93m>>> \033[0m").strip()

            if not prompt:
                continue

            if prompt.lower() in {"exit", "quit", "q"}:
                print("\033[90mGoodbye.\033[0m")
                break

            print(self.run(prompt))


def run(
    account_login: int,
    account_password: str,
    broker_server_name: str,
    api_key: str,
    model: int = DEEPSEEK,
    prompt: Optional[str] = None,
) -> Optional[str]:
    """Convenience API.

    If prompt is provided, returns a single response.
    If prompt is omitted, starts interactive mode.
    """
    agent = Agent(
        api_key=api_key,
        account_login=account_login,
        account_password=account_password,
        broker_server_name=broker_server_name,
        model=model,
    )

    if prompt is None:
        agent.chat()
        return None

    return agent.run(prompt)
