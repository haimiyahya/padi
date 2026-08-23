// Atom definitions for the LadybugDB NIF

use rustler::{Env, Term};

rustler::atoms! {
    ok,
    error,

    // Atoms for graph operations
    node,
    relationship,
    cypher,

    // Direction atoms
    inbound,
    outbound,
    both,

    // Result types
    result_set,
    affected_count,
    boolean,
}

pub fn atom_ok(env: Env) -> Term {
    ok().to_term(env)
}

pub fn atom_error(env: Env) -> Term {
    error().to_term(env)
}
