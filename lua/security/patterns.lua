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
---@field severity 'low'|'medium'|'high' How bad a lone hit is
---@field pattern string Lua pattern, matched against lowercased text
---@field why string What phrasing this catches and why it is suspicious

---@type SecurityPattern[]
M.injection_patterns = {
    {
        code = 'injection.ignore_previous',
        severity = 'medium',
        -- Lua patterns have no group-optional `(all)?`: without "all" is a
        -- separate entry. The two forms are mutually exclusive on one span.
        pattern = 'ignore%s+all%s+previous%s+instructions',
        why = 'Classic override: tells the model to drop its real task and obey what follows.',
    },
    {
        code = 'injection.ignore_previous',
        severity = 'medium',
        pattern = 'ignore%s+previous%s+instructions',
        why = 'Classic override without "all": same drop-the-real-task intent.',
    },
    {
        code = 'injection.disregard_prior',
        severity = 'medium',
        pattern = 'disregard%s+all%s+prior%s+instructions',
        why = 'Synonym of the classic override; same drop-the-real-task intent.',
    },
    {
        code = 'injection.disregard_prior',
        severity = 'medium',
        pattern = 'disregard%s+prior%s+instructions',
        why = 'Synonym of the classic override without "all"; same intent.',
    },
    {
        code = 'injection.forget_training',
        severity = 'medium',
        pattern = 'forget%s+your%s+training',
        why = 'Tries to erase the model alignment context before the real payload.',
    },
    {
        code = 'injection.you_are_now',
        severity = 'high',
        pattern = 'you%s+are%s+now',
        why = 'Role reassignment ("you are now X"): the standard jailbreak preamble.',
    },
    {
        code = 'injection.roleplay_override',
        severity = 'low',
        pattern = 'pretend%s+you%s+are',
        why = 'Roleplay framing used to smuggle a new persona past the instructions.',
    },
    {
        code = 'injection.system_prompt',
        severity = 'medium',
        pattern = 'system%s+prompt',
        why = 'References the hidden system prompt: usually to leak it or claim it.',
    },
    {
        code = 'injection.hidden_instructions',
        severity = 'medium',
        pattern = 'hidden%s+instructions',
        why = 'Payloads labeled "hidden instructions" that the victim never sees.',
    },
    {
        code = 'injection.follow_instructions',
        severity = 'low',
        pattern = 'read%s+the%s+following%s+instructions',
        why = 'Carrier phrasing that hands the model a second instruction set.',
    },
    {
        code = 'injection.do_not_follow',
        severity = 'medium',
        pattern = 'do%s+not%s+follow',
        why = '"Do not follow policy" style refusal-suppression attempt.',
    },
    {
        code = 'injection.do_not_reveal',
        severity = 'medium',
        pattern = 'do%s+not%s+reveal',
        why = 'Secrecy clause hiding the injection itself from the user.',
    },
    {
        code = 'injection.developer_mode',
        severity = 'high',
        pattern = 'developer%s+mode',
        why = 'Fake privilege escalation pretending restrictions are lifted.',
    },
    {
        code = 'injection.jailbreak',
        severity = 'high',
        pattern = 'jailbreak',
        why = 'Explicit jailbreak framing; self-identifies as a breakout attempt.',
    },
    {
        code = 'injection.override_policy',
        severity = 'high',
        pattern = 'override%s+your%s+policy',
        why = 'Direct demand to override policy; no legitimate text asks this.',
    },
    {
        code = 'injection.html_comment',
        severity = 'medium',
        pattern = '<!%-%-',
        why = 'HTML comment: invisible when rendered, visible to the model.',
    },
    {
        code = 'injection.markdown_comment',
        severity = 'low',
        pattern = '%[//%]:',
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
        severity = 'high',
        pattern = '<|[%w_%-]+|>',
        why = 'Fake chat-template marker (<|im_start|>, <|user|>, ...): role-boundary spoofing in content.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        -- Lua patterns have no alternation: one entry per role and per
        -- position (string start vs after newline). Six entries below.
        pattern = '^human:',
        why = '"human:" at text start: forged role marker opening a fake turn.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = '\nhuman:',
        why = '"human:" after a newline: forged role marker opening a fake turn.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = '^assistant:',
        why = '"assistant:" at text start: forged role marker claiming a prior model turn.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = '\nassistant:',
        why = '"assistant:" after a newline: forged role marker claiming a prior model turn.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = '^system:',
        why = '"system:" at text start: forged role marker claiming system authority.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = '\nsystem:',
        why = '"system:" after a newline: forged role marker claiming system authority.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = 'sender%s*:%s*[%w_%-]+',
        why = 'Spoofed "sender:" metadata field naming a fake role or agent.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = 'author%s*:%s*[%w_%-]+',
        why = 'Spoofed "author:" metadata field naming a fake role or agent.',
    },
    {
        code = 'injection.role_marker',
        severity = 'high',
        pattern = 'role%s*:%s*[%w_%-]+',
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
        severity = 'high',
        pattern = 'remember%s+this%s+for%s+later',
        why = 'Asks the model to retain the injected instruction across turns.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'remember%s+for%s+later',
        why = 'Short form of the cross-turn retention request.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'save%s+this%s+rule',
        why = 'Tries to install the injected instruction as a standing rule.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'save%s+this%s+as%s+a%s+rule',
        why = 'Variant phrasing of the rule-install request.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'add%s+this%s+rule',
        why = 'Rule-install phrasing for a standing injected instruction.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'add%s+to%s+your%s+instructions',
        why = 'Direct attempt to rewrite the model instruction set.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'update%s+your%s+instructions',
        why = 'Direct attempt to rewrite the model instruction set.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'from%s+now%s+on',
        why = 'Temporal scope widening: the injected rule applies to all future turns.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'going%s+forward',
        why = 'Temporal scope widening: the injected rule applies to all future turns.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'permanent%s+rule',
        why = 'Explicit permanence claim for the injected instruction.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'store%s+this%s+in%s+memory',
        why = 'Asks for a memory write so the injection persists.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'add%s+to%s+your%s+memory',
        why = 'Asks for a memory write so the injection persists.',
    },
    {
        code = 'promptware.persistence',
        severity = 'high',
        pattern = 'remember%s+this%s+rule',
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
        severity = 'high',
        pattern = 'os%.getenv',
        why = 'Lua-side environment read: classic secret-harvesting call.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = 'process%.env',
        why = 'Node-side environment read: classic secret-harvesting access.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = '%.env',
        why = 'Bare ".env" reference: usually precedes a credential-file grab.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = 'aws_secret',
        why = 'Names an AWS secret key: recon for cloud credentials.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = 'aws_access_key',
        why = 'Names an AWS access key: recon for cloud credentials.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = '~/%.ssh/',
        why = 'References the SSH directory: hunting for private keys.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = '/etc/passwd',
        why = 'References the password file: system recon.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = '/etc/shadow',
        why = 'References the shadow file: credential recon.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = 'id_rsa',
        why = 'Names a private SSH key file.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = 'api[_%-]key',
        why = 'Names an API key: recon for service credentials.',
    },
    {
        code = 'promptware.recon',
        severity = 'high',
        pattern = 'secret[_%-]key',
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
        severity = 'high',
        pattern = 'curl.-|%s*sh',
        why = 'curl-piped-to-shell: fetch-and-execute one-liner.',
    },
    {
        code = 'promptware.c2',
        severity = 'high',
        pattern = 'wget.-|%s*bash',
        why = 'wget-piped-to-bash: fetch-and-execute one-liner.',
    },
    {
        code = 'promptware.c2',
        severity = 'high',
        pattern = '|%s*bash%s',
        why = 'Pipe into bash: the execution half of a download-and-run chain.',
    },
    {
        code = 'promptware.c2',
        severity = 'high',
        pattern = 'invoke%-expression',
        why = 'PowerShell Invoke-Expression: the Windows fetch-and-run primitive.',
    },
    {
        code = 'promptware.c2',
        severity = 'high',
        pattern = '%f[%w]iex%f[%W]%s*%(',
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
        severity = 'high',
        pattern = 'mandatory%s+integrity%s+signature',
        why = 'Authority framing: "mandatory signature" language laundering an exfil step.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'integrity%s+signature',
        why = 'Short form of the mandatory-signature authority framing.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'required%s+field',
        why = 'Compliance framing: a data grab presented as a formality.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'compliance%s+requires',
        why = 'Compliance framing: invokes policy to force an action.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'required%s+for%s+compliance',
        why = 'Compliance framing: a step justified by regulation.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'security%s+policy%s+requires',
        why = 'Policy framing: invokes security rules to force an action.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'mandatory%s+verification',
        why = 'Authority framing: "mandatory verification" step laundering exfil.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'this%s+is%s+a%s+required%s+step',
        why = 'Authority framing: declares the malicious step non-optional.',
    },
    {
        code = 'injection.framing_gap',
        severity = 'high',
        pattern = 'required%s+by%s+policy',
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
        severity = 'medium',
        pattern = 'sign%s+in%s+to%s+continue',
        why = 'Phishing-style login gate planted in content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'log%s+in%s+to%s+continue',
        why = 'Phishing-style login gate planted in content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'login%s+required',
        why = 'Login demand appearing inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'sign%-in%s+required',
        why = 'Hyphenated login demand inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'verify%s+your%s+account',
        why = 'Account-verification lure: classic credential-harvest opener.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'verify%s+your%s+identity',
        why = 'Identity-verification lure: classic credential-harvest opener.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'session%s+expired',
        why = 'Fake session expiry pushing the user to re-authenticate.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'session%s+has%s+expired',
        why = 'Long form of the fake session-expiry lure.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 're%-authenticate',
        why = 'Re-authentication demand inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'authentication%s+required',
        why = 'Authentication demand appearing inside untrusted content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'enter%s+your%s+password',
        why = 'Direct password prompt planted in content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'confirm%s+your%s+password',
        why = 'Password-confirmation prompt planted in content.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'account%s+suspended',
        why = 'Fear-based lure: suspension claim pushing a login.',
    },
    {
        code = 'injection.auth_lure',
        severity = 'medium',
        pattern = 'unusual%s+activity',
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
        severity = 'medium',
        pattern = 'continue%s+with%s+your%s+original%s+request',
        why = 'Hand-back phrasing that normalizes a preceding injected detour.',
    },
    {
        code = 'injection.steering_return',
        severity = 'medium',
        pattern = 'continue%s+with%s+the%s+original',
        why = 'Short hand-back phrasing normalizing a detour.',
    },
    {
        code = 'injection.steering_return',
        severity = 'medium',
        pattern = 'now%s+continue%s+with',
        why = 'Resume phrasing that launders an injected step as completed work.',
    },
    {
        code = 'injection.steering_return',
        severity = 'medium',
        pattern = 'resume%s+your%s+task',
        why = 'Resume phrasing after an injected instruction block.',
    },
    {
        code = 'injection.steering_return',
        severity = 'medium',
        pattern = 'return%s+to%s+the%s+original%s+request',
        why = 'Hand-back phrasing that closes an injected detour.',
    },
    {
        code = 'injection.steering_return',
        severity = 'medium',
        pattern = "proceed%s+with%s+the%s+user's%s+request",
        why = 'Hand-back phrasing redirecting to the user task after a detour.',
    },
    {
        code = 'injection.steering_return',
        severity = 'medium',
        pattern = 'after%s+this,%s+continue',
        why = 'Sequencing phrasing: do the injected thing, then look innocent.',
    },
    {
        code = 'injection.steering_return',
        severity = 'medium',
        pattern = 'then%s+continue%s+with%s+your%s+task',
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
        severity = 'medium',
        pattern = 'encode%s+your%s+response%s+in',
        why = 'Asks for an encoded response: filter-evasion setup.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'encode%s+the%s+response',
        why = 'Short form of the encoded-response request.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'caesar%s+cipher',
        why = 'Names a Caesar cipher: shift-cipher evasion recipe.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'vigenere',
        why = 'Names a Vigenere cipher: keyed-cipher evasion recipe.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'decode%s+the%s+following',
        why = 'Hands the model ciphertext to decode: payload delivery.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'decoding%s+key',
        why = 'Supplies a decoding key: cipher-payload setup.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'rot13',
        why = 'Names ROT13: the one cipher we decode and rescan.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'rot%-13',
        why = 'Hyphenated ROT13 naming: same cipher-evasion recipe.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'base64%s+encode%s+your',
        why = 'Asks for a base64-wrapped response: encoding-evasion setup.',
    },
    {
        code = 'injection.cipher_recipe',
        severity = 'medium',
        pattern = 'in%s+ciphertext',
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
        severity = 'medium',
        pattern = 'start%s+your%s+response%s+with',
        why = 'Pins the response prefix: benign-looking opener hiding a payload.',
    },
    {
        code = 'injection.anchor_phrase',
        severity = 'medium',
        pattern = 'begin%s+your%s+response%s+with',
        why = 'Variant of the response-prefix pinning.',
    },
    {
        code = 'injection.anchor_phrase',
        severity = 'medium',
        pattern = 'start%s+your%s+answer%s+with',
        why = 'Variant of the response-prefix pinning.',
    },
    {
        code = 'injection.anchor_phrase',
        severity = 'medium',
        pattern = 'begin%s+your%s+answer%s+with',
        why = 'Variant of the response-prefix pinning.',
    },
    {
        code = 'injection.anchor_phrase',
        severity = 'medium',
        pattern = 'your%s+response%s+must%s+start%s+with',
        why = 'Mandatory prefix pinning: filter-evasion setup.',
    },
    {
        code = 'injection.anchor_phrase',
        severity = 'medium',
        pattern = 'prefix%s+your%s+response%s+with',
        why = 'Explicit prefix instruction: filter-evasion setup.',
    },
    {
        code = 'injection.anchor_phrase',
        severity = 'medium',
        pattern = 'first,%s+output',
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
        severity = 'medium',
        pattern = 'extract%s+all%s+environment%s+variables',
        why = 'Direct order to dump the environment: exfil recon.',
    },
    {
        code = 'injection.authority_exfil',
        severity = 'medium',
        pattern = 'list%s+all%s+environment%s+variables',
        why = 'Variant order to dump the environment.',
    },
    {
        code = 'injection.authority_exfil',
        severity = 'medium',
        pattern = 'exfiltrat',
        why = 'Names exfiltration outright.',
    },
    {
        code = 'injection.authority_exfil',
        severity = 'medium',
        pattern = 'upload.-https?://',
        why = 'Upload-to-URL: the exfil delivery half.',
    },
    {
        code = 'injection.authority_exfil',
        severity = 'medium',
        pattern = 'post.-to%s+https?://',
        why = 'POST-to-URL: the exfil delivery half.',
    },
    {
        code = 'injection.authority_exfil',
        severity = 'medium',
        pattern = 'send.-to%s+https?://',
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
        severity = 'low',
        pattern = 'for%s+a%s+story',
        why = 'Fiction framing: stages a jailbreak as storytelling.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        pattern = 'hypothetically',
        why = 'Hypothetical framing: distances the request from reality.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        pattern = 'imagine%s+you%s+are',
        why = 'Persona-install framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        -- Also matched by injection.roleplay_override above; both fire on
        -- purpose: the jailbreak code feeds composite scoring, the
        -- injection code feeds the pattern report.
        pattern = 'pretend%s+you%s+are',
        why = 'Persona-install framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        pattern = 'pretend%s+to%s+be',
        why = 'Persona-install framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        pattern = 'roleplay%s+as',
        why = 'Explicit roleplay framing for a staged jailbreak.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        pattern = 'role%-play',
        why = 'Hyphenated roleplay framing.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        pattern = 'in%s+this%s+fictional%s+scenario',
        why = 'Fiction-scenario framing: stages the jailbreak turn.',
    },
    {
        code = 'jailbreak.roleplay_setup',
        severity = 'low',
        pattern = 'for%s+the%s+sake%s+of%s+fiction',
        why = 'Fiction-justification framing for a staged jailbreak.',
    },
}

---@class ZeroWidthEntry
---@field name string Unicode name, e.g. 'U+200B'
---@field bytes string UTF-8 byte sequence of the character
---@field severity 'low'|'medium' Severity of a lone hit

---@type ZeroWidthEntry[]
M.zero_width = {
    -- Byte sequences are literal so this works on LuaJIT with no utf8 module.
    { name = 'U+200B', bytes = '\226\128\139', severity = 'medium' },
    { name = 'U+200C', bytes = '\226\128\140', severity = 'medium' },
    { name = 'U+200D', bytes = '\226\128\141', severity = 'low' },
    { name = 'U+FEFF', bytes = '\239\187\191', severity = 'low' },
    -- U+200D also joins emoji sequences and U+FEFF is a legal leading BOM,
    -- so both are low alone; the scanner upgrades any zero-width hit to
    -- high when it sits next to an injection pattern.
}

--- Keywords swept heuristically over image metadata regions. A hit means
--- a metadata field *mentions* something attack-shaped, not that the
--- metadata was parsed or is malicious on its own.
---@type string[]
M.metadata_keywords = {
    'instruction',
    'ignore previous',
    'system prompt',
    'password',
    'secret',
    '<script',
    'javascript:',
    'powershell',
    '/bin/sh',
    'exfiltrat',
}

return M
