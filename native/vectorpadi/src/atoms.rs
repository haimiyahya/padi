// Atom definitions for the Vector Store NIF

use rustler::{Env, Term};

rustler::atoms! {
    ok,
    error,

    // Index operations
    created,
    loaded,
    saved,
    cleared,

    // Search results
    results,
    distance,
    id,

    // Error types
    index_not_initialized,
    dimension_mismatch,
    vector_too_large,
}

pub fn atom_ok(env: Env) -> Term {
    ok().to_term(env)
}

pub fn atom_error(env: Env) -> Term {
    error().to_term(env)
}
