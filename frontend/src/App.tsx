import { useState } from "react";
import { countCharacters } from "./api";
import "./App.css";

export default function App() {
  const [text, setText] = useState("");
  const [count, setCount] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleCount = async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await countCharacters(text);
      setCount(result.count);
    } catch {
      setError("Failed to count characters.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app">
      <h1>Character Counter</h1>
      <textarea
        className="input"
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Enter text here..."
        rows={6}
      />
      <button className="button" onClick={handleCount} disabled={loading}>
        {loading ? "Counting..." : "Count"}
      </button>
      {count !== null && <p className="result">Characters: {count}</p>}
      {error && <p className="error">{error}</p>}
    </div>
  );
}
