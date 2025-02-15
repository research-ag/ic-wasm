#!ic-repl
// Check if the transformed Wasm module can be deployed

function install(wasm) {
  let id = call ic.provisional_create_canister_with_cycles(record { settings = null; amount = null });
  let S = id.canister_id;
  call ic.install_code(
    record {
      arg = encode ();
      wasm_module = wasm;
      mode = variant { install };
      canister_id = S;
    }
  );
  S
};
function upgrade(S, wasm) {
  call ic.install_code(
    record {
      arg = encode ();
      wasm_module = wasm;
      mode = variant { upgrade };
      canister_id = S;
    }
  );
};

function counter(wasm) {
  let S = install(wasm);
  call S.set(42);
  call S.inc();
  call S.get();
  assert _ == (43 : nat);

  call S.inc();
  call S.inc();
  call S.get();
  assert _ == (45 : nat);
  S
};
function wat(wasm) {
  let S = install(wasm);
  call S.set((42 : int64));
  call S.inc();
  call S.get();
  assert _ == (43 : int64);

  call S.inc();
  call S.inc();
  call S.get();
  assert _ == (45 : int64);
  S
};
function classes(wasm) {
  let S = install(wasm);
  call S.get(42);
  assert _ == (null : opt empty);
  call S.put(42, "text");
  call S.get(42);
  assert _ == opt "text";

  call S.put(40, "text0");
  call S.put(41, "text1");
  call S.put(42, "text2");
  call S.get(42);
  assert _ == opt "text2";
  read_state("canister", S, "metadata/candid:args");
  assert _ == "()";
  read_state("canister", S, "metadata/motoko:compiler");
  assert _ == blob "0.6.26";
  S
};
function classes_limit(wasm) {
  let S = install(wasm);
  call S.get(42);
  assert _ == (null : opt empty);
  fail call S.put(42, "text");
  assert _ ~= "0 cycles were received";
  S
};
function classes_redirect(wasm) {
  let S = install(wasm);
  call S.get(42);
  assert _ == (null : opt empty);
  fail call S.put(42, "text");
  assert _ ~= "zz73r-nyaaa-aabbb-aaaca-cai not found";
  S
};
function check_profiling(S, cycles, len) {
  call S.__get_cycles();
  assert _ == (cycles : int64);
  call S.__get_profiling((0:nat32));
  assert _[0].size() == (len : nat);
  assert _[1] == (null : opt empty);
  call S.__get_profiling((1:nat32));
  assert _[0].size() == (sub(len,1) : nat);
  null
};
function evm_redirect(wasm) {
  let S = install(wasm);
  fail call S.request();
  assert _ ~= "zz73r-nyaaa-aabbb-aaaca-cai not found";
  fail call S.requestCost();
  assert _ ~= "7hfb6-caaaa-aaaar-qadga-cai not found";
  fail call S.non_evm_request();
  assert _ ~= "cpmcr-yeaaa-aaaaa-qaala-cai not found";
  S
};

evm_redirect(file("ok/evm-redirect.wasm"));

let S = counter(file("ok/motoko-instrument.wasm"));
check_profiling(S, 21571, 78);
let S = counter(file("ok/motoko-gc-instrument.wasm"));
check_profiling(S, 595, 4);
let wasm = file("ok/motoko-region-instrument.wasm");
let S = counter(wasm);
check_profiling(S, 478652, 78);
upgrade(S, wasm);
call S.get();
assert _ == (45 : nat);
check_profiling(S, 494682, 460);
counter(file("ok/motoko-shrink.wasm"));
counter(file("ok/motoko-limit.wasm"));

let S = counter(file("ok/rust-instrument.wasm"));
check_profiling(S, 75279, 576);
let wasm = file("ok/rust-region-instrument.wasm");
let S = counter(wasm);
check_profiling(S, 152042, 574);
upgrade(S, wasm);
call S.get();
assert _ == (45 : nat);
check_profiling(S, 1023168, 2344);
counter(file("ok/rust-shrink.wasm"));
counter(file("ok/rust-limit.wasm"));

let S = wat(file("ok/wat-instrument.wasm"));
check_profiling(S, 5656, 2);
wat(file("ok/wat-shrink.wasm"));
wat(file("ok/wat-limit.wasm"));

classes(file("ok/classes-shrink.wasm"));
classes(file("ok/classes-optimize.wasm"));
classes(file("ok/classes-optimize-names.wasm"));
classes_limit(file("ok/classes-limit.wasm"));
classes_redirect(file("ok/classes-redirect.wasm"));
classes(file("ok/classes-nop-redirect.wasm"));
