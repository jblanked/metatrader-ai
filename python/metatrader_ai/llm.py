OPENAI = 0
DEEPSEEK = 1
ANTHROPIC = 2
LOCAL = 3

class LLM:
    """LLM provider config with endpoint URL, model name, and API key."""
    __slots__ = ["provider_id", "id", "label", "model", "url"]

    def __init__(self, provider_id: int = DEEPSEEK):
        self.id = ""
        self.label = ""
        self.model = ""
        self.url = ""

        if provider_id == OPENAI:
            self.id = "openai"
            self.label = "OpenAI"
            self.model = "gpt-5.4-mini"
            self.url = "https://api.openai.com/v1/chat/completions"
        elif provider_id == DEEPSEEK:
            self.id = "deepseek"
            self.label = "DeepSeek"
            self.model = "deepseek-v4-flash"
            self.url = "https://api.deepseek.com/chat/completions"
        elif provider_id == ANTHROPIC:
            self.id = "anthropic"
            self.label = "Anthropic"
            self.model = "claude-sonnet-5"
            self.url = "https://api.anthropic.com/v1/messages"
        elif provider_id == LOCAL:
            self.id = "local"
            self.label = "Local"
            self.model = " "
            self.url = "http://127.0.0.1:8080/v1/chat/completions"
        else:
            raise ValueError("Invalid provider_id. Must be 0 (OpenAI), 1 (DeepSeek), 2 (Anthropic), or 3 (Local).")
    