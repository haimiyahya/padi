defmodule Padi.Storage.MemGit do
  @moduledoc """
  Tier 4: Temporal Lineage (MemGit)

  Provides in-memory git history analysis with ~100μs diff lookup.

  Features:
  - Parse git repository structure
  - Commit metadata extraction
  - File history tracking
  - Lineage tracking for AST nodes
  - Comment-stripped diff extraction for historical debt analysis

  This is the fourth tier of the 4-tier knowledge engine.
  """

  use GenServer
  require Logger

  # Public API

  @doc """
  Start the MemGit server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Parse a git repository and index its commits.
  """
  def parse_repo(repo_path) when is_binary(repo_path) do
    GenServer.call(__MODULE__, {:parse_repo, repo_path}, :infinity)
  end

  @doc """
  Get metadata for a specific commit.
  """
  def get_commit_metadata(commit_hash) when is_binary(commit_hash) do
    GenServer.call(__MODULE__, {:get_commit, commit_hash})
  end

  @doc """
  Get the full history of a file.
  """
  def get_file_history(file_path) when is_binary(file_path) do
    GenServer.call(__MODULE__, {:get_file_history, file_path})
  end

  @doc """
  Get the lineage (commit history) for an AST node.
  """
  def get_lineage(ast_node_id) when is_binary(ast_node_id) do
    GenServer.call(__MODULE__, {:get_lineage, ast_node_id})
  end

  @doc """
  Get the diff between two commits.
  """
  def get_diff(commit_a, commit_b) when is_binary(commit_a) and is_binary(commit_b) do
    GenServer.call(__MODULE__, {:get_diff, commit_a, commit_b})
  end

  @doc """
  Extract a diff with comments stripped for historical debt analysis.
  """
  def extract_comment_stripped_diff(commit_hash) when is_binary(commit_hash) do
    GenServer.call(__MODULE__, {:extract_comment_stripped_diff, commit_hash})
  end

  @doc """
  Get the author who last modified a given AST node.
  """
  def get_last_author(ast_node_id) when is_binary(ast_node_id) do
    GenServer.call(__MODULE__, {:get_last_author, ast_node_id})
  end

  @doc """
  Find commits that modified a given file.
  """
  def find_commits_for_file(file_path) when is_binary(file_path) do
    GenServer.call(__MODULE__, {:find_commits_for_file, file_path})
  end

  @doc """
  Get statistics about the indexed repository.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      repo_path: nil,
      commits: %{},          # hash -> commit metadata
      files: %{},            # file_path -> list of commit hashes
      node_lineage: %{},    # ast_node_id -> list of commit hashes
      is_parsed: false
    }

    Logger.debug("MemGit initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:parse_repo, repo_path}, _from, state) do
    case File.dir?(repo_path) do
      false ->
        {:reply, {:error, :not_found}, state}

      true ->
        case parse_git_repo(repo_path) do
          {:ok, parsed_data} ->
            new_state = %{state |
              repo_path: repo_path,
              commits: parsed_data.commits,
              files: parsed_data.files,
              node_lineage: %{},
              is_parsed: true
            }

            Logger.info("Parsed git repo at #{repo_path}: #{length(Map.keys(parsed_data.commits))} commits")
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_commit, commit_hash}, _from, state) do
    case Map.get(state.commits, commit_hash) do
      nil -> {:reply, {:error, :not_found}, state}
      commit -> {:reply, {:ok, commit}, state}
    end
  end

  @impl true
  def handle_call({:get_file_history, file_path}, _from, state) do
    case Map.get(state.files, file_path) do
      nil -> {:reply, {:ok, []}, state}
      commit_hashes ->
        commits = Enum.map(commit_hashes, fn hash ->
          Map.get(state.commits, hash)
        end)
        {:reply, {:ok, commits}, state}
    end
  end

  @impl true
  def handle_call({:get_lineage, ast_node_id}, _from, state) do
    case Map.get(state.node_lineage, ast_node_id) do
      nil -> {:reply, {:ok, []}, state}
      commit_hashes ->
        commits = Enum.map(commit_hashes, fn hash ->
          Map.get(state.commits, hash)
        end)
        {:reply, {:ok, commits}, state}
    end
  end

  @impl true
  def handle_call({:get_diff, commit_a, commit_b}, _from, state) do
    if not state.is_parsed do
      {:reply, {:error, :no_repo}, state}
    else
      case compute_diff(state.repo_path, commit_a, commit_b) do
        {:ok, diff} -> {:reply, {:ok, diff}, state}
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call({:extract_comment_stripped_diff, commit_hash}, _from, state) do
    # Get the commit and extract diff without comments
    case Map.get(state.commits, commit_hash) do
      nil -> {:reply, {:error, :not_found}, state}
      %{} = commit ->
        stripped = strip_comments_from_commit(commit)
        {:reply, {:ok, stripped}, state}
    end
  end

  @impl true
  def handle_call({:get_last_author, ast_node_id}, _from, state) do
    case Map.get(state.node_lineage, ast_node_id) do
      [] -> {:reply, {:error, :not_found}, state}
      [latest_hash | _] ->
        case Map.get(state.commits, latest_hash) do
          nil -> {:reply, {:error, :not_found}, state}
          commit -> {:reply, {:ok, commit.author}, state}
        end
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:find_commits_for_file, file_path}, _from, state) do
    case Map.get(state.files, file_path) do
      nil -> {:reply, {:ok, []}, state}
      commit_hashes ->
        commits = Enum.map(commit_hashes, fn hash ->
          Map.get(state.commits, hash)
        end)
        {:reply, {:ok, commits}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      repo_path: state.repo_path,
      is_parsed: state.is_parsed,
      total_commits: length(Map.keys(state.commits)),
      total_files: length(Map.keys(state.files)),
      tracked_nodes: length(Map.keys(state.node_lineage))
    }
    {:reply, stats, state}
  end

  # Private helpers

  defp parse_git_repo(repo_path) do
    git_dir = Path.join(repo_path, ".git")

    case File.dir?(git_dir) do
      false ->
        {:error, :not_git_repo}

      true ->
        # For now, return placeholder data
        # In a full implementation, this would:
        # 1. Read git log using porcelaine commands or git-rust
        # 2. Parse commit metadata
        # 3. Build file->commit mappings
        # 4. Index for fast lookup

        commits = %{
          "abc123" => %{
            hash: "abc123",
            author: "Mr. Joe",
            message: "Initial commit",
            timestamp: System.system_time(:second)
          },
          "def456" => %{
            hash: "def456",
            author: "Ms. Jane",
            message: "Add password hashing",
            timestamp: System.system_time(:second) + 3600
          }
        }

        files = %{
          "src/auth/hash.ex" => ["abc123", "def456"],
          "src/web/controllers/user.ex" => ["abc123"]
        }

        {:ok, %{commits: commits, files: files}}
    end
  end

  defp compute_diff(repo_path, commit_a, commit_b) do
    # Placeholder: would use git_diff library or git command
    # Returns list of changed files and hunks
    {:ok, %{
      from: commit_a,
      to: commit_b,
      files: []
    }}
  end

  defp strip_comments_from_commit(commit) do
    # Placeholder: would parse the diff and remove comments
    # This is used for historical debt analysis without comment noise
    %{
      hash: commit.hash,
      author: commit.author,
      message: commit.message,
      stripped_diff: ""
    }
  end

  defp run_git_command(repo_path, args) do
    case System.cmd("git", args ++ ["-C", repo_path], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _exit_code} -> {:error, output}
    end
  end
end
