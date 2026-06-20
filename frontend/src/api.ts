const API_URL = import.meta.env.VITE_API_URL;

export interface CountResponse {
  count: number;
}

export async function countCharacters(text: string): Promise<CountResponse> {
  const res = await fetch(`${API_URL}/count`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text }),
  });
  if (!res.ok) {
    throw new Error(`HTTP error: ${res.status}`);
  }
  return res.json() as CountResponse;
}
