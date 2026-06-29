import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";

export function SessionSearchBar() {
  const [value, setValue] = useState("");
  const navigate = useNavigate();

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    const trimmed = value.trim();
    if (!trimmed) {
      return;
    }
    navigate(`/sessions/${trimmed}`);
  }

  return (
    <form className="search-bar" onSubmit={onSubmit}>
      <input
        value={value}
        onChange={(event) => setValue(event.target.value)}
        placeholder="Jump to sessionId"
        aria-label="Search by session ID"
      />
      <button type="submit">Open</button>
    </form>
  );
}
