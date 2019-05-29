defmodule GenStageExample do
  defmodule GetHTTP do
    use GenStage

    def init(page) do
      HTTPoison.start()
      url =  "http://version1.api.memegenerator.net//Instances_Select_ByPopular?languageCode=en&pageIndex=" <>
             "#{page}" <>
             "&urlName=&days=&apiKey=demo"
      {:producer, {url, page}}
    end

    def handle_demand(_demand, {url, page}) do
      memes = get_json(url)
      url =  "http://version1.api.memegenerator.net//Instances_Select_ByPopular?languageCode=en&pageIndex=" <>
             "#{page+1}" <>
             "&urlName=t&days=&apiKey=demo"
      {:noreply, memes, {url, page+1}}
    end

    def get_json(url) do
      %HTTPoison.Response{body: body} = HTTPoison.get!(url)
      body = Poison.Parser.parse!(body, %{})
      body["result"]
    end
  end

  defmodule Filter do
    use GenStage

    def init({filter_field, filter_value}) do
      {:producer_consumer, {filter_field, filter_value}}
    end

    def handle_events(events, _from, {filter_field, filter_value} = state) do
      events = Enum.filter(events, &(&1[filter_field] > filter_value))
      {:noreply, events, state}
    end
  end

  defmodule Unpack do
    use GenStage

    def init(element) do
      {:producer_consumer, element}
    end

    def handle_events(events, _from, element) do
      events = Enum.map(events, &(&1[element]))
      {:noreply, events, element}
    end
  end

  defmodule Ticker do
    use GenStage

    def init(sleep_time) do
      {:consumer, sleep_time}
    end

    def handle_events(events, _from, sleep_time) do
      IO.inspect(events)
      Process.sleep(sleep_time)
      {:noreply, [], sleep_time}
    end
  end

  {:ok, gethttp} = GenStage.start_link(GetHTTP, 0)
  {:ok, filter} = GenStage.start_link(Filter, {"totalVotesScore", 100})
  {:ok, unpack} = GenStage.start_link(Unpack, "instanceUrl")
  {:ok, ticker} = GenStage.start_link(Ticker, 1_000)

  GenStage.sync_subscribe(filter, to: gethttp, max_demand: 1)
  GenStage.sync_subscribe(unpack, to: filter)
  GenStage.sync_subscribe(ticker, to: unpack)

  Process.sleep(:infinity)
end
