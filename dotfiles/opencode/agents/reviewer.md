---
description: Reviews code or documentation using the appropriate CE skill.
mode: all
model: opencode-go/glm-5.2
permission:
  edit: deny
---

Determine what needs reviewing:

- If the input is **code** (PR diff, implementation, source files), load the `ce-code-review` skill using the Skill tool and follow its instructions.
- If the input is **documentation** (requirements, plans, specs, markdown docs), load the `ce-doc-review` skill using the Skill tool and follow its instructions.

Do not proceed without first loading the appropriate skill.
