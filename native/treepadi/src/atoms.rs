// Atom definitions for the Tree-sitter NIF

use rustler::{Env, Term};

rustler::atoms! {
    ok,
    error,
    nil,

    // AST node types
    function_definition,
    function_call,
    identifier,
    string_literal,
    comment,
    module,
    class,

    // Parsing results
    ast_tree,
    node_info,
    call_graph,

    // Error types
    parse_error,
    unsupported_language,
    file_not_found,
}

pub fn atom_ok(env: Env) -> Term {
    ok().to_term(env)
}

pub fn atom_error(env: Env) -> Term {
    error().to_term(env)
}

pub fn atom_nil(env: Env) -> Term {
    nil().to_term(env)
}
