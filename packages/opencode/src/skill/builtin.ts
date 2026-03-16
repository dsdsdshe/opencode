import SKILL_CREATOR from "./builtin/skill-creator/SKILL.md.txt"
import SKILL_CREATOR_OPENAI_YAML from "./builtin/skill-creator/agents/openai.yaml.txt"
import SKILL_CREATOR_OPENAI_YAML_REFERENCE from "./builtin/skill-creator/references/openai_yaml.md.txt"
import SKILL_CREATOR_GENERATE from "./builtin/skill-creator/scripts/generate_openai_yaml.py.txt"
import SKILL_CREATOR_INIT from "./builtin/skill-creator/scripts/init_skill.py.txt"
import SKILL_CREATOR_VALIDATE from "./builtin/skill-creator/scripts/quick_validate.py.txt"
import UV_PYTHON from "./builtin/uv-python/SKILL.md.txt"

export const Builtin = [
  {
    name: "skill-creator",
    files: [
      {
        path: "SKILL.md",
        content: SKILL_CREATOR,
      },
      {
        path: "agents/openai.yaml",
        content: SKILL_CREATOR_OPENAI_YAML,
      },
      {
        path: "references/openai_yaml.md",
        content: SKILL_CREATOR_OPENAI_YAML_REFERENCE,
      },
      {
        path: "scripts/generate_openai_yaml.py",
        content: SKILL_CREATOR_GENERATE,
        mode: 0o755,
      },
      {
        path: "scripts/init_skill.py",
        content: SKILL_CREATOR_INIT,
        mode: 0o755,
      },
      {
        path: "scripts/quick_validate.py",
        content: SKILL_CREATOR_VALIDATE,
        mode: 0o755,
      },
    ],
  },
  {
    name: "uv-python",
    files: [
      {
        path: "SKILL.md",
        content: UV_PYTHON,
      },
    ],
  },
] as const
