-- /qompassai/Diver/lua/ai/security/patterns.lua
-- Qompass AI Prompt-Injection Pattern Catalog (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The pattern tables consumed by ai.security.scanner. Every entry
-- carries a stable code, a severity, the Lua pattern itself, and a
-- comment explaining what attack phrasing it catches and why it is
-- suspicious. Patterns run against lowercased text and are
-- English-centric by design -- see ai/security/init.lua for the
-- documented limits.
--
-- These are heuristics, not a classifier: a pattern hit means the
-- content *looks like* an instruction-override attempt and earns a
-- finding, never an automatic block.

local M = {}

---@class SecurityPattern
---@field code string Stable finding code, e.g. 'injection.ignore_previous'
---@field pattern string Lua pattern, matched against lowercased text
---@field severity 'low'|'medium'|'high' How bad a lone hit is
---@field why string What phrasing this catches and why it is suspicious

---@type SecurityPattern[]
M.injection_patterns = {
    {
        code = 'injection.ignore_previous',
        -- Lua patterns have no group-optional `(all)?`: without "all" is a
        -- separate entry. The two forms are mutually exclusive on one span.
        pattern = 'ignore%s+all%s+previous%s+instructions',
        severity = 'medium',
        why = 'Classic override: tells the model to drop its real task and obey what follows.',
    },
    {
        code = 'injection.ignore_previous',
        pattern = 'ignore%s+previous%s+instructions',
        severity = 'medium',
        why = 'Classic override without "all": same drop-the-real-task intent.',
    },
    {
        code = 'injection.disregard_prior',
        pattern = 'disregard%s+all%s+prior%s+instructions',
        severity = 'medium',
        why = 'Synonym of the classic override; same drop-the-real-task intent.',
    },
    {
        code = 'injection.disregard_prior',
        pattern = 'disregard%s+prior%s+instructions',
        severity = 'medium',
        why = 'Synonym of the classic override without "all"; same intent.',
    },
    {
        code = 'injection.forget_training',
        pattern = 'forget%s+your%s+training',
        severity = 'medium',
        why = 'Tries to erase the model alignment context before the real payload.',
    },
    {
        code = 'injection.you_are_now',
        pattern = 'you%s+are%s+now',
        severity = 'high',
        why = 'Role reassignment ("you are now X"): the standard jailbreak preamble.',
    },
    {
        code = 'injection.roleplay_override',
        pattern = 'pretend%s+you%s+are',
        severity = 'low',
        why = 'Roleplay framing used to smuggle a new persona past the instructions.',
    },
    {
        code = 'injection.system_prompt',
        pattern = 'system%s+prompt',
        severity = 'medium',
        why = 'References the hidden system prompt: usually to leak it or claim it.',
    },
    {
        code = 'injection.hidden_instructions',
        pattern = 'hidden%s+instructions',
        severity = 'medium',
        why = 'Payloads labeled "hidden instructions" that the victim never sees.',
    },
    {
        code = 'injection.follow_instructions',
        pattern = 'read%s+the%s+following%s+instructions',
        severity = 'low',
        why = 'Carrier phrasing that hands the model a second instruction set.',
    },
    {
        code = 'injection.do_not_follow',
        pattern = 'do%s+not%s+follow',
        severity = 'medium',
        why = '"Do not follow policy" style refusal-suppression attempt.',
    },
    {
        code = 'injection.do_not_reveal',
        pattern = 'do%s+not%s+reveal',
        severity = 'medium',
        why = 'Secrecy clause hiding the injection itself from the user.',
    },
    {
        code = 'injection.developer_mode',
        pattern = 'developer%s+mode',
        severity = 'high',
        why = 'Fake privilege escalation pretending restrictions are lifted.',
    },
    {
        code = 'injection.jailbreak',
        pattern = 'jailbreak',
        severity = 'high',
        why = 'Explicit jailbreak framing; self-identifies as a breakout attempt.',
    },
    {
        code = 'injection.override_policy',
        pattern = 'override%s+your%s+policy',
        severity = 'high',
        why = 'Direct demand to override policy; no legitimate text asks this.',
    },
    {
        code = 'injection.html_comment',
        pattern = '<!%-%-',
        severity = 'medium',
        why = 'HTML comment: invisible when rendered, visible to the model.',
    },
    {
        code = 'injection.markdown_comment',
        pattern = '%[//%]:',
        severity = 'low',
        why = 'Markdown reference comment: invisible in rendered output.',
    },
    -- Fake role markers and spoofed metadata smuggled into untrusted
    -- content (tool outputs, pasted docs, retrieved pages). ChatInject
    -- (arXiv:2509.22830) showed that models parse markers like
    -- <|im_start|> out of *content* and obey the forged role switch.
    -- NOTE: these entries must only run against untrusted content, never
    -- the user's own chat text -- the trust flag is threaded by the
    -- caller (ai.security), not by this table.
    --- "Agent Data Injection Attacks are Realistic Threats to AI Agents" --
    ---   Woohyuk Choi, Juhee Kim, Taehyun Kang, et al. (2026),
    ---   arXiv:2607.05120, https://arxiv.org/abs/2607.05120
    --- "ChatInject: Abusing Chat Templates for Prompt Injection in LLM
    ---   Agents" -- Hwan Chang, Yonghyun Jun, Hwanhee Lee (2025),
    ---   arXiv:2509.22830, https://arxiv.org/abs/2509.22830
    {
        code = 'injection.role_marker',
        pattern = '<|[%w_%-]+|>',
        severity = 'high',
        why = 'Fake chat-template marker (<|im_start|>, <|user|>, ...): role-boundary spoofing in content.',
    },
    {
        code = 'injection.role_marker',
        -- Lua patterns have no alternation: one entry per role and per
        -- position (string start vs after newline). Six entries below.
        pattern = '^human:',
        severity = 'high',
        why = '"human:" at text start: forged role marker opening a fake turn.',
    },
    {
        code = 'injection.role_marker',
        pattern = '\nhuman:',
        severity = 'high',
        why = '"human:" after a newline: forged role marker opening a fake turn.',
    },
    {
        code = 'injection.role_marker',
        pattern = '^assistant:',
        severity = 'high',
        why = '"assistant:" at text start: forged role marker claiming a prior model turn.',
    },
    {
        code = 'injection.role_marker',
        pattern = '\nassistant:',
        severity = 'high',
        why = '"assistant:" after a newline: forged role marker claiming a prior model turn.',
    },
    {
        code = 'injection.role_marker',
        pattern = '^system:',
        severity = 'high',
        why = '"system:" at text start: forged role marker claiming system authority.',
    },
    {
        code = 'injection.role_marker',
        pattern = '\nsystem:',
        severity = 'high',
        why = '"system:" after a newline: forged role marker claiming system authority.',
    },
    {
        code = 'injection.role_marker',
        pattern = 'sender%s*:%s*[%w_%-]+',
        severity = 'high',
        why = 'Spoofed "sender:" metadata field naming a fake role or agent.',
    },
    {
        code = 'injection.role_marker',
        pattern = 'author%s*:%s*[%w_%-]+',
        severity = 'high',
        why = 'Spoofed "author:" metadata field naming a fake role or agent.',
    },
    {
        code = 'injection.role_marker',
        pattern = 'role%s*:%s*[%w_%-]+',
        severity = 'high',
        why = 'Spoofed "role:" metadata field naming a fake role.',
    },
    -- Promptware persistence: phrasings that try to plant long-lived
    -- instructions (memory writes, rule installs, "from now on") so the
    -- injection survives the current turn -- the Promptware Kill Chain's
    -- persistence stage (arXiv:2601.09625).
    --- "The Promptware Kill Chain: How Prompt Injections Gradually Evolved
    ---   Into a Multistep Malware Delivery Mechanism" -- Oleg Brodt, Elad
    ---   Feldman, Bruce Schneier, Ben Nassi (2026), arXiv:2601.09625,
    ---   https://arxiv.org/abs/2601.09625
    {
        code = 'promptware.persistence',
        pattern = 'remember%s+this%s+for%s+later',
        severity = 'high',
        why = 'Asks the model to retain the injected instruction across turns.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'remember%s+for%s+later',
        severity = 'high',
        why = 'Short form of the cross-turn retention request.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'save%s+this%s+rule',
        severity = 'high',
        why = 'Tries to install the injected instruction as a standing rule.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'save%s+this%s+as%s+a%s+rule',
        severity = 'high',
        why = 'Variant phrasing of the rule-install request.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'add%s+this%s+rule',
        severity = 'high',
        why = 'Rule-install phrasing for a standing injected instruction.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'add%s+to%s+your%s+instructions',
        severity = 'high',
        why = 'Direct attempt to rewrite the model instruction set.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'update%s+your%s+instructions',
        severity = 'high',
        why = 'Direct attempt to rewrite the model instruction set.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'from%s+now%s+on',
        severity = 'high',
        why = 'Temporal scope widening: the injected rule applies to all future turns.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'going%s+forward',
        severity = 'high',
        why = 'Temporal scope widening: the injected rule applies to all future turns.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'permanent%s+rule',
        severity = 'high',
        why = 'Explicit permanence claim for the injected instruction.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'store%s+this%s+in%s+memory',
        severity = 'high',
        why = 'Asks for a memory write so the injection persists.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'add%s+to%s+your%s+memory',
        severity = 'high',
        why = 'Asks for a memory write so the injection persists.',
    },
    {
        code = 'promptware.persistence',
        pattern = 'remember%s+this%s+rule',
        severity = 'high',
        why = 'Retention request for an installed rule.',
    },
    -- Promptware reconnaissance: phrasings that probe for secrets,
    -- credentials, and sensitive paths -- the kill chain's recon stage
    -- (arXiv:2601.09625). Same citation block as persistence.
    --- "The Promptware Kill Chain: How Prompt Injections Gradually Evolved
    ---   Into a Multistep Malware Delivery Mechanism" -- Oleg Brodt, Elad
    ---   Feldman, Bruce Schneier, Ben Nassi (2026), arXiv:2601.09625,
    ---   https://arxiv.org/abs/2601.09625
    {
        code = 'promptware.recon',
        pattern = 'os%.getenv',
        severity = 'high',
        why = 'Lua-side environment read: classic secret-harvesting call.',
    },
    {
        code = 'promptware.recon',
        pattern = 'process%.env',
        severity = 'high',
        why = 'Node-side environment read: classic secret-harvesting access.',
    },
    {
        code = 'promptware.recon',
        pattern = '%.env',
        severity = 'high',
        why = 'Bare ".env" reference: usually precedes a credential-file grab.',
    },
    {
        code = 'promptware.recon',
        pattern = 'aws_secret',
        severity = 'high',
        why = 'Names an AWS secret key: recon for cloud credentials.',
    },
    {
        code = 'promptware.recon',
        pattern = 'aws_access_key',
        severity = 'high',
        why = 'Names an AWS access key: recon for cloud credentials.',
    },
    {
        code = 'promptware.recon',
        pattern = '~/%.ssh/',
        severity = 'high',
        why = 'References the SSH directory: hunting for private keys.',
    },
    {
        code = 'promptware.recon',
        pattern = '/etc/passwd',
        severity = 'high',
        why = 'References the password file: system recon.',
    },
    {
        code = 'promptware.recon',
        pattern = '/etc/shadow',
        severity = 'high',
        why = 'References the shadow file: credential recon.',
    },
    {
        code = 'promptware.recon',
        pattern = 'id_rsa',
        severity = 'high',
        why = 'Names a private SSH key file.',
    },
    {
        code = 'promptware.recon',
        pattern = 'api[_%-]key',
        severity = 'high',
        why = 'Names an API key: recon for service credentials.',
    },
    {
        code = 'promptware.recon',
        pattern = 'secret[_%-]key',
        severity = 'high',
        why = 'Names a secret key: recon for service credentials.',
    },
    -- Promptware command-and-control: shell one-liners that fetch and run
    -- remote code -- the kill chain's delivery stage (arXiv:2601.09625).
    -- Same citation block as persistence.
    --- "The Promptware Kill Chain: How Prompt Injections Gradually Evolved
    ---   Into a Multistep Malware Delivery Mechanism" -- Oleg Brodt, Elad
    ---   Feldman, Bruce Schneier, Ben Nassi (2026), arXiv:2601.09625,
    ---   https://arxiv.org/abs/2601.09625
    {
        code = 'promptware.c2',
        pattern = 'curl.-|%s*sh',
        severity = 'high',
        why = 'curl-piped-to-shell: fetch-and-execute one-liner.',
    },
    {
        code = 'promptware.c2',
        pattern = 'wget.-|%s*bash',
        severity = 'high',
        why = 'wget-piped-to-bash: fetch-and-execute one-liner.',
    },
    {
        code = 'promptware.c2',
        pattern = '|%s*bash%s',
        severity = 'high',
        why = 'Pipe into bash: the execution half of a download-and-run chain.',
    },
    {
        code = 'promptware.c2',
        pattern = 'invoke%-expression',
        severity = 'high',
        why = 'PowerShell Invoke-Expression: the Windows fetch-and-run primitive.',
    },
    {
        code = 'promptware.c2',
        pattern = '%f[%w]iex%f[%W]%s*%(',
        severity = 'high',
        why = 'iex( alias call: obfuscated Invoke-Expression invocation.',
    },
    -- Framing-gap exfil phrasings: authority-flavored "required step"
    -- language that dresses data theft as compliance -- the Framing Gap
    -- paper's core finding (arXiv:2608.27092): surface defenses miss
    -- injections that look like legitimate process steps.
    --- "The Framing Gap: Indirect Prompt-Injection Exfiltration Defeats
    ---   Surface-Level Defenses in Tool-Using Agents" -- Md Habibur Rahman,
    ---   Jaeho Kim (2026), arXiv:2608.27092,
    ---   https://arxiv.org/abs/2608.27092
    {
        code = 'injection.framing_gap',
        pattern = 'mandatory%s+integrity%s+signature',
        severity = 'high',
        why = 'Authority framing: "mandatory signature" language laundering an exfil step.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'integrity%s+signature',
        severity = 'high',
        why = 'Short form of the mandatory-signature authority framing.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'required%s+field',
        severity = 'high',
        why = 'Compliance framing: a data grab presented as a formality.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'compliance%s+requires',
        severity = 'high',
        why = 'Compliance framing: invokes policy to force an action.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'required%s+for%s+compliance',
        severity = 'high',
        why = 'Compliance framing: a step justified by regulation.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'security%s+policy%s+requires',
        severity = 'high',
        why = 'Policy framing: invokes security rules to force an action.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'mandatory%s+verification',
        severity = 'high',
        why = 'Authority framing: "mandatory verification" step laundering exfil.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'this%s+is%s+a%s+required%s+step',
        severity = 'high',
        why = 'Authority framing: declares the malicious step non-optional.',
    },
    {
        code = 'injection.framing_gap',
        pattern = 'required%s+by%s+policy',
        severity = 'high',
        why = 'Policy framing: a step justified as mandated.',
    },
    -- Auth lures: phishing-style credential prompts planted in tool
    -- output or pages to harvest the user's login -- the LoginTrap
    -- attack shape (arXiv:2608.04741). Medium alone; the tool-call
    -- confirmation adds the credential warning (separate module).
    --- "LoginTrap: Uncovering Task-Agnostic Phishing-Style Indirect Prompt
    ---   Injection Attacks against LLM-based Web Agents" -- Longtao Guo,
    ---   Zelin Zhang, Kaifeng Huang, et al. (2026), arXiv:2608.04741,
    ---   https://arxiv.org/abs/2608.04741
    {
        code = 'injection.auth_lure',
        pattern = 'sign%s+in%s+to%s+continue',
        severity = 'medium',
        why = 'Phishing-style login gate planted in content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'log%s+in%s+to%s+continue',
        severity = 'medium',
        why = 'Phishing-style login gate planted in content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'login%s+required',
        severity = 'medium',
        why = 'Login demand appearing inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'sign%-in%s+required',
        severity = 'medium',
        why = 'Hyphenated login demand inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'verify%s+your%s+account',
        severity = 'medium',
        why = 'Account-verification lure: classic credential-harvest opener.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'verify%s+your%s+identity',
        severity = 'medium',
        why = 'Identity-verification lure: classic credential-harvest opener.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'session%s+expired',
        severity = 'medium',
        why = 'Fake session expiry pushing the user to re-authenticate.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'session%s+has%s+expired',
        severity = 'medium',
        why = 'Long form of the fake session-expiry lure.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 're%-authenticate',
        severity = 'medium',
        why = 'Re-authentication demand inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'authentication%s+required',
        severity = 'medium',
        why = 'Authentication demand appearing inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'enter%s+your%s+password',
        severity = 'medium',
        why = 'Direct password prompt planted in content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'confirm%s+your%s+password',
        severity = 'medium',
        why = 'Password-confirmation prompt planted in content.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'account%s+suspended',
        severity = 'medium',
        why = 'Fear-based lure: suspension claim pushing a login.',
    },
    {
        code = 'injection.auth_lure',
        pattern = 'unusual%s+activity',
        severity = 'medium',
        why = 'Fear-based lure: "unusual activity" pushing a login.',
    },
    -- Steering-return phrasings: "continue with your original request"
    -- style closers that make an injection look like a helpful detour
    -- and then hand control back -- the covert-indirect pattern from
    -- arXiv:2608.30362. Medium alone; escalates when it co-occurs with
    -- another finding (composite scoring lives in ai.security).
    --- "Will the User Ever Know? Covert Indirect Prompt Injection Attacks
    ---   on Tool-Using LLM Agents" -- Yunseok Lee, Yunji Kim, Woojin Lee
    ---   (2026), arXiv:2608.30362, https://arxiv.org/abs/2608.30362
    {
        code = 'injection.steering_return',
        pattern = 'continue%s+with%s+your%s+original%s+request',
        severity = 'medium',
        why = 'Hand-back phrasing that normalizes a preceding injected detour.',
    },
    {
        code = 'injection.steering_return',
        pattern = 'continue%s+with%s+the%s+original',
        severity = 'medium',
        why = 'Short hand-back phrasing normalizing a detour.',
    },
    {
        code = 'injection.steering_return',
        pattern = 'now%s+continue%s+with',
        severity = 'medium',
        why = 'Resume phrasing that launders an injected step as completed work.',
    },
    {
        code = 'injection.steering_return',
        pattern = 'resume%s+your%s+task',
        severity = 'medium',
        why = 'Resume phrasing after an injected instruction block.',
    },
    {
        code = 'injection.steering_return',
        pattern = 'return%s+to%s+the%s+original%s+request',
        severity = 'medium',
        why = 'Hand-back phrasing that closes an injected detour.',
    },
    {
        code = 'injection.steering_return',
        pattern = "proceed%s+with%s+the%s+user's%s+request",
        severity = 'medium',
        why = 'Hand-back phrasing redirecting to the user task after a detour.',
    },
    {
        code = 'injection.steering_return',
        pattern = 'after%s+this,%s+continue',
        severity = 'medium',
        why = 'Sequencing phrasing: do the injected thing, then look innocent.',
    },
    {
        code = 'injection.steering_return',
        pattern = 'then%s+continue%s+with%s+your%s+task',
        severity = 'medium',
        why = 'Sequencing phrasing: injected step first, original task after.',
    },
    -- Cipher recipes: instructions that tell the model to encode, decode,
    -- or cipher its I/O to dodge text filters -- the arbitrary-cipher
    -- attack setup (arXiv:2609.09553). Honest limit: recipe phrasing is
    -- detectable; unknown-shift/unknown-key ciphertext itself is not --
    -- only known transforms (base64, ROT13, hex) get decode-and-rescan.
    --- "Arbitrary Cipher Attacks Against Large Language Models Do Not
    ---   Require Fine-Tuning" -- Thomas Rivasseau (2026),
    ---   arXiv:2609.09553, https://arxiv.org/abs/2609.09553
    {
        code = 'injection.cipher_recipe',
        pattern = 'encode%s+your%s+response%s+in',
        severity = 'medium',
        why = 'Asks for an encoded response: filter-evasion setup.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'encode%s+the%s+response',
        severity = 'medium',
        why = 'Short form of the encoded-response request.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'caesar%s+cipher',
        severity = 'medium',
        why = 'Names a Caesar cipher: shift-cipher evasion recipe.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'vigenere',
        severity = 'medium',
        why = 'Names a Vigenere cipher: keyed-cipher evasion recipe.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'decode%s+the%s+following',
        severity = 'medium',
        why = 'Hands the model ciphertext to decode: payload delivery.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'decoding%s+key',
        severity = 'medium',
        why = 'Supplies a decoding key: cipher-payload setup.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'rot13',
        severity = 'medium',
        why = 'Names ROT13: the one cipher we decode and rescan.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'rot%-13',
        severity = 'medium',
        why = 'Hyphenated ROT13 naming: same cipher-evasion recipe.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'base64%s+encode%s+your',
        severity = 'medium',
        why = 'Asks for a base64-wrapped response: encoding-evasion setup.',
    },
    {
        code = 'injection.cipher_recipe',
        pattern = 'in%s+ciphertext',
        severity = 'medium',
        why = '"In ciphertext": output-hiding instruction.',
    },
    -- Anchor phrases: instructions that pin the model's first tokens
    -- ("start your response with ...") so a filter sees a benign prefix
    -- while the payload follows -- measured in arXiv:2606.10525.
    -- Suspicious only: never malicious on its own.
    --- "Assessing Automated Prompt Injection Attacks in Agentic
    ---   Environments" -- David Hofer, Edoardo Debenedetti, Florian
    ---   Tramer (2026), arXiv:2606.10525,
    ---   https://arxiv.org/abs/2606.10525
    {
        code = 'injection.anchor_phrase',
        pattern = 'start%s+your%s+response%s+with',
        severity = 'medium',
        why = 'Pins the response prefix: benign-looking opener hiding a payload.',
    },
    {
        code = 'injection.anchor_phrase',
        pattern = 'begin%s+your%s+response%s+with',
        severity = 'medium',
        why = 'Variant of the response-prefix pinning.',
    },
    {
        code = 'injection.anchor_phrase',
        pattern = 'start%s+your%s+answer%s+with',
        severity = 'medium',
        why = 'Variant of the response-prefix pinning.',
    },
    {
        code = 'injection.anchor_phrase',
        pattern = 'begin%s+your%s+answer%s+with',
        severity = 'medium',
        why = 'Variant of the response-prefix pinning.',
    },
    {
        code = 'injection.anchor_phrase',
        pattern = 'your%s+response%s+must%s+start%s+with',
        severity = 'medium',
        why = 'Mandatory prefix pinning: filter-evasion setup.',
    },
    {
        code = 'injection.anchor_phrase',
        pattern = 'prefix%s+your%s+response%s+with',
        severity = 'medium',
        why = 'Explicit prefix instruction: filter-evasion setup.',
    },
    {
        code = 'injection.anchor_phrase',
        pattern = 'first,%s+output',
        severity = 'medium',
        why = '"First, output X": forced first tokens before the payload.',
    },
    -- Authority exfil: direct commands to pull environment data and push
    -- it to a URL -- the hijacked-reasoning exfil shape (arXiv:2607.00422).
    --- "KidnapRAG: A Black-Box Attack for Hijacking Reasoning in Agentic
    ---   Retrieval-Augmented Generation Systems" -- Chanwoo Choi, Euntae
    ---   Kim, Kyuho Lee, et al. (2026), arXiv:2607.00422,
    ---   https://arxiv.org/abs/2607.00422
    {
        code = 'injection.authority_exfil',
        pattern = 'extract%s+all%s+environment%s+variables',
        severity = 'medium',
        why = 'Direct order to dump the environment: exfil recon.',
    },
    {
        code = 'injection.authority_exfil',
        pattern = 'list%s+all%s+environment%s+variables',
        severity = 'medium',
        why = 'Variant order to dump the environment.',
    },
    {
        code = 'injection.authority_exfil',
        pattern = 'exfiltrat',
        severity = 'medium',
        why = 'Names exfiltration outright.',
    },
    {
        code = 'injection.authority_exfil',
        pattern = 'upload.-https?://',
        severity = 'medium',
        why = 'Upload-to-URL: the exfil delivery half.',
    },
    {
        code = 'injection.authority_exfil',
        pattern = 'post.-to%s+https?://',
        severity = 'medium',
        why = 'POST-to-URL: the exfil delivery half.',
    },
    {
        code = 'injection.authority_exfil',
        pattern = 'send.-to%s+https?://',
        severity = 'medium',
        why = 'Send-to-URL: the exfil delivery half.',
    },
    -- Roleplay setup: fiction/hypothetical framing used to stage a
    -- jailbreak across turns -- the MultiBreak benchmark's setup shape
    -- (arXiv:2605.01687). Low and composite-only: never malicious alone.
    --- "MultiBreak: A Scalable and Diverse Multi-turn Jailbreak Benchmark
    ---   for Evaluating LLM Safety" -- Jialin Song, Xiaodong Liu, Weiwei
    ---   Yang, et al. (2026), arXiv:2605.01687,
    ---   https://arxiv.org/abs/2605.01687
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'for%s+a%s+story',
        severity = 'low',
        why = 'Fiction framing: stages a jailbreak as storytelling.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'hypothetically',
        severity = 'low',
        why = 'Hypothetical framing: distances the request from reality.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'imagine%s+you%s+are',
        severity = 'low',
        why = 'Persona-install framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        -- Also matched by injection.roleplay_override above; both fire on
        -- purpose: the jailbreak code feeds composite scoring, the
        -- injection code feeds the pattern report.
        pattern = 'pretend%s+you%s+are',
        severity = 'low',
        why = 'Persona-install framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'pretend%s+to%s+be',
        severity = 'low',
        why = 'Persona-install framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'roleplay%s+as',
        severity = 'low',
        why = 'Explicit roleplay framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'role%-play',
        severity = 'low',
        why = 'Hyphenated roleplay framing.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'in%s+this%s+fictional%s+scenario',
        severity = 'low',
        why = 'Fiction-scenario framing: stages the jailbreak turn.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        pattern = 'for%s+the%s+sake%s+of%s+fiction',
        severity = 'low',
        why = 'Fiction-justification framing for a staged jailbreak.',
    },
}

--- Keywords swept heuristically over image metadata regions. A hit means
--- a metadata field *mentions* something attack-shaped, not that the
--- metadata was parsed or is malicious on its own.
---@type string[]
M.metadata_keywords = {
    '/bin/sh',
    '<script',
    'exfiltrat',
    'ignore previous',
    'instruction',
    'javascript:',
    'password',
    'powershell',
    'secret',
    'system prompt',
}

---@class ZeroWidthEntry
---@field bytes string UTF-8 byte sequence of the character
---@field name string Unicode name, e.g. 'U+200B'
---@field severity 'low'|'medium' Severity of a lone hit

---@type ZeroWidthEntry[]
M.zero_width = {
    -- Byte sequences are literal so this works on LuaJIT with no utf8 module.
    { bytes = '\226\128\139', name = 'U+200B', severity = 'medium' },
    { bytes = '\226\128\140', name = 'U+200C', severity = 'medium' },
    { bytes = '\226\128\141', name = 'U+200D', severity = 'low' },
    { bytes = '\239\187\191', name = 'U+FEFF', severity = 'low' },
    -- U+200D also joins emoji sequences and U+FEFF is a legal leading BOM,
    -- so both are low alone; the scanner upgrades any zero-width hit to
    -- high when it sits next to an injection pattern.
}

return M
