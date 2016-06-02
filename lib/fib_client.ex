defmodule FibClient do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    {:ok, connection} = AMQP.Connection.open

    receiver_pool_opts = [
      {:name, {:local, :receiver_pool}},
      {:worker_module, FibClient.Receiver},
      {:size, 30},
      {:max_overflow, 5}
    ]

    children = [
      # Define workers and child supervisors to be supervised
      # worker(FibClient.Worker, [arg1, arg2, arg3]),
      :poolboy.child_spec(:receiver_pool, receiver_pool_opts, [connection])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FibClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
