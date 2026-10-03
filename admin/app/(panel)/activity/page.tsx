"use client";

import { useState } from "react";
import { ActivityList } from "@/components/activity";
import { Card, ErrorNote, ExportButton, Loading, PageHeader, cx, inputClass } from "@/components/ui";
import { csvDate, downloadCsv } from "@/lib/csv";
import { AREAS, area, recentActivity, sentence } from "@/lib/activity";
import { useLoad } from "@/lib/use-load";

export default function ActivityPage() {
  const { data, error, loading } = useLoad(() => recentActivity());
  const [admin, setAdmin] = useState("");
  const [kind, setKind] = useState("");
  const [search, setSearch] = useState("");

  const admins = [...new Set((data ?? []).map((e) => e.byUsername ?? (e.by === "system" ? "system" : "")).filter(Boolean))].sort();
  const q = search.trim().toLowerCase();
  const shown = (data ?? []).filter(
    (e) =>
      (!admin || (e.byUsername ?? (e.by === "system" ? "system" : "")) === admin) &&
      (!kind || area(e.action) === kind) &&
      (!q || `${sentence(e)} ${e.snippet ?? ""} ${e.reason ?? ""}`.toLowerCase().includes(q)),
  );

  return (
    <>
      <PageHeader
        title="Activity"
        subtitle="Every change an admin made, newest first. Nobody can edit or delete this record."
        actions={
          <ExportButton
            disabled={!shown.length}
            onClick={() =>
              downloadCsv("admin-activity", ["when", "admin", "what", "about", "words", "reason"],
                shown.map((e) => [csvDate(e.at), e.by === "system" ? "automatic" : (e.byUsername ?? e.by), sentence(e), e.username ?? e.author ?? e.communityName ?? "", e.snippet, e.reason]))
            }
          />
        }
      />
      <Card className="mb-4">
        <div className="grid gap-3 sm:grid-cols-3">
          <input className={inputClass} placeholder="Search names and words" value={search} onChange={(e) => setSearch(e.target.value)} />
          <select className={inputClass} value={admin} onChange={(e) => setAdmin(e.target.value)} aria-label="Admin">
            <option value="">Every admin</option>
            {admins.map((a) => <option key={a} value={a}>{a === "system" ? "Automatic" : `@${a}`}</option>)}
          </select>
          <select className={inputClass} value={kind} onChange={(e) => setKind(e.target.value)} aria-label="Kind">
            <option value="">Everything</option>
            {AREAS.map((a) => <option key={a} value={a}>{a}</option>)}
          </select>
        </div>
      </Card>
      <ErrorNote error={error} />
      <Card title={data ? `${shown.length} ${shown.length === 1 ? "change" : "changes"}` : "Changes"} flush className={cx(loading && "opacity-90")}>
        {loading && !data ? <Loading /> : <ActivityList entries={shown} empty={q || admin || kind ? "Nothing matches" : undefined} />}
      </Card>
    </>
  );
}
