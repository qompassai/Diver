"""Deterministic, schema-checking stdio peer; no network or credentials."""
import argparse, base64, json, sys, time
from pathlib import Path
import jsonschema
p = argparse.ArgumentParser()
p.add_argument('--version', type=int, required=True)
p.add_argument('--log', required=True)
p.add_argument('--login', action='store_true')
p.add_argument('--login-delay', type=float, default=0)
a = p.parse_args()
if a.login: time.sleep(a.login_delay); sys.exit(0)
v = a.version
d = json.loads((Path(__file__).parent/'schema'/f'v{v}.json').read_text())['$defs']
validators = {(x['x-method'], 'response' if n.endswith('Response') else 'request'):
    jsonschema.Draft202012Validator({'$defs': d, **x}) for n, x in d.items() if 'x-method' in x}
log = open(a.log, 'a', buffering=1)
pending, serial, root, prompt_id = {}, 1000, None, None
client_requests = {}
sid = f'mock-v{v}'
def send(message) -> None:
    for item in message if isinstance(message,list) else [message]:
        if 'method' in item:
            validator = validators.get((item['method'], 'request'))
            value = item.get('params', {})
        else:
            validator = validators.get((client_requests.get(item.get('id')), 'response'))
            value = item.get('result')
        if validator and 'error' not in item: validator.validate(value)
    raw = json.dumps(message, separators=(',', ':'))+'\n'
    mid = len(raw)//2
    sys.stdout.write(raw[:mid]); sys.stdout.flush()
    time.sleep(.002)
    sys.stdout.write(raw[mid:]); sys.stdout.flush()
def reply(ident, result) -> None: send({'jsonrpc':'2.0', 'id':ident, 'result':result})
def update(value) -> None: send({'jsonrpc':'2.0', 'method':'session/update', 'params':{'sessionId':sid,'update':value}})
def req(method: str, params, cb) -> None:
    global serial
    serial += 1
    ident = f'agent-{serial}'
    pending[ident] = method, cb
    send({'jsonrpc':'2.0','id':ident,'method':method,'params':params})
def options() -> list[dict[str, bool | str] | dict[str, list[dict[str, str]] | str]]:
    key = 'configId' if v==2 else 'id'
    return [{key:'model','type':'select','name':'Model','currentValue':'a','options':[{'name':'A','value':'a'},{'name':'B','value':'b'}]},
        {key:'thinking','name':'Thinking','type':'boolean','currentValue':False}]
def finish(reason: str='end_turn') -> None:
    global prompt_id
    if v==1: reply(prompt_id, {'stopReason':reason})
    else: update({'sessionUpdate':'state_update','state':'idle','stopReason':reason})
    prompt_id = None
def messages() -> None:
    for text in ['hello ', 'world']:
        update({'sessionUpdate':'agent_message_chunk','content':{'type':'text','text':text}, **({'messageId':'answer'} if v==2 else {})})
    update({'sessionUpdate':'available_commands_update','availableCommands':[{'name':'help','description':'Help'}]})
    update({'sessionUpdate':'config_option_update','configOptions':options()})
    update({'sessionUpdate':'tool_call_update' if v==2 else 'tool_call','toolCallId':'tool','title':'Read','status':'in_progress','kind':'read'})
    plan = {'entries':[{'content':'Test','priority':'high','status':'completed'}]}
    update({'sessionUpdate':'plan',**plan} if v==1 else {'sessionUpdate':'plan_update','plan':{'type':'items','planId':'plan',**plan}})
    update({'sessionUpdate':'tool_call_update','toolCallId':'tool','status':'completed'})
    if v==2:
        raw = 'λ\x1b]52;c;c2VjcmV0\x07\ntext'.encode()
        update({'sessionUpdate':'terminal_update','terminalId':'display','command':'echo','output':{'data':base64.b64encode(raw[:1]).decode()}})
        update({'sessionUpdate':'terminal_output_chunk','terminalId':'display','data':base64.b64encode(raw[1:]).decode()})
def elicitation() -> None:
    def done(m) -> None:
        assert m['result']=={'action':'accept','content':{'enabled':False,'name':'fixture'}},m
        finish()
    req('elicitation/create',{'sessionId':sid,'mode':'form','message':'Mock form','requestedSchema':{
        'type':'object','properties':{'enabled':{'type':'boolean'},'name':{'type':'string','minLength':1}},'required':['enabled','name']}},done)
def files() -> None:
    def read_done(m) -> None:
        assert m['result']['content']=='unsaved editor text\n',m
        req('fs/write_text_file',{'sessionId':sid,'path':str(Path(root)/'written.txt'),'content':'written by mock\n'},write_done)
    def write_done(m) -> None:
        assert 'error' not in m,m
        req('terminal/create',{'sessionId':sid,'command':sys.executable,'args':['-c','print("terminal content")'],'outputByteLimit':1024},created)
    def created(m) -> None:
        params={'sessionId':sid,'terminalId':m['result']['terminalId']}
        def exited(r) -> None:
            assert r['result']['exitCode']==0,r
            req('terminal/output',params,output)
        def output(r) -> None:
            assert 'terminal content' in r['result']['output'],r
            req('terminal/release',params,lambda r:elicitation())
        req('terminal/wait_for_exit',params,exited)
    req('fs/read_text_file',{'sessionId':sid,'path':str(Path(root)/'source.txt')},read_done)
def permission() -> None:
    params={'sessionId':sid,'options':[{'optionId':'no','name':'Reject','kind':'reject_once'},{'optionId':'yes','name':'Allow','kind':'allow_once'}]}
    if v==1: params['toolCall']={'toolCallId':'tool','title':'Read fixture'}
    else: params.update(title='Read fixture',subject={'type':'command','command':'echo test','cwd':root})
    def done(m) -> None:
        assert m['result']['outcome']=={'outcome':'selected','optionId':'yes'},m
        files() if v==1 else elicitation()
    req('session/request_permission',params,done)
def dispatch(m) -> None:
    global root,prompt_id
    log.write(json.dumps({'version':v,'message':m})+'\n')
    if 'method' not in m:
        method,cb=pending.pop(m['id'])
        validator=validators.get((method,'response'))
        if validator and 'error' not in m: validator.validate(m['result'])
        cb(m);return
    method,params=m['method'],m.get('params',{})
    validator=validators.get((method,'request'))
    if validator: validator.validate(params)
    ident=m.get('id')
    if ident is not None: client_requests[ident] = method
    if method=='initialize':
        caps={'loadSession':True,'promptCapabilities':{'embeddedContext':True,'image':True,'audio':True},'mcpCapabilities':{'http':True,'sse':True},'auth':{'logout':{}},'sessionCapabilities':{k:{} for k in ['list','resume','close','delete','additionalDirectories']}}
        if v==2: caps={'session':{'prompt':{'embeddedContext':{},'image':{},'audio':{}},'mcp':{'stdio':{},'http':{}},'delete':{},'additionalDirectories':{}}}
        key='methodId' if v==2 else 'id'
        reply(ident,{'protocolVersion':v,'authMethods':[{key:'login','name':'Login','type':'agent'},{key:'terminal','name':'Terminal login','type':'terminal','args':['--login']}],
            'capabilities' if v==2 else 'agentCapabilities':caps,'info' if v==2 else 'agentInfo':{'name':'mock','version':'1.0'}})
    elif method in ['session/new','session/load','session/resume']:
        root=params['cwd']
        if method!='session/new':update({'sessionUpdate':'agent_message_chunk','content':{'type':'text','text':'replayed'},**({'messageId':'replay'} if v==2 else {})})
        result={'configOptions':options()}
        if method=='session/new':result['sessionId']=sid
        if v==1:result['modes']={'currentModeId':'safe','availableModes':[{'id':'safe','name':'Safe'}]}
        reply(ident,result)
    elif method=='session/prompt':
        prompt_id=ident;text=params['prompt'][0].get('text','')
        if v==2:reply(ident,{'messageId':'user-'+str(ident)});update({'sessionUpdate':'state_update','state':'running'})
        if text=='wait':return
        messages()
        permission() if text=='exercise' else finish()
    elif method=='session/cancel':
        if prompt_id is not None:finish('cancelled')
    elif method=='session/set_config_option':reply(ident,{'configOptions':options()})
    elif method=='session/list':reply(ident,{'sessions':[{'sessionId':sid,'cwd':root,'title':'Mock'}]})
    elif method in ['authenticate','auth/login','logout','auth/logout','session/set_mode','session/close','session/delete']:reply(ident,{})
    elif method in ['_timeout','$/cancel_request']:pass
    elif method=='_batch':
        def done(r) -> None:assert r['result']=={'ok':True},r
        for ident2 in ['batch-a','batch-b']:pending[ident2]=('_client',done)
        send([{'jsonrpc':'2.0','id':i,'method':'_client','params':{}} for i in ['batch-a','batch-b']]);reply(ident,{})
    elif method=='_exit':sys.exit(7)
    elif method=='_false':reply(ident,False)
    elif method=='_cancel_incoming':
        def cancelled(r) -> None: assert r['error']['code']==-32800,r
        req('_cancel_me',{},cancelled)
        send({'jsonrpc':'2.0','method':'$/cancel_request','params':{'requestId':f'agent-{serial}'}})
        reply(ident,{})
    elif method=='_overflow':
        sys.stdout.write('x' * (17 * 1024 * 1024)); sys.stdout.flush();time.sleep(2)
    elif method.startswith('_'):reply(ident,{'echo':params})
    else:raise AssertionError(method)
for line in sys.stdin:
    value=json.loads(line)
    for item in value if isinstance(value,list) else [value]:dispatch(item)
