import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { examsApi } from "../../services/api";
import { getStoredUser } from "../../utils/auth";
import { Alert, Badge, Button, Field, Modal, PageHeader, StatCard, fmtDateTime, inputCls } from "../../components/ui";

const isImage = (f) => /\.(png|jpe?g|gif|webp|heic)$/i.test(f.name || f.url || "");

/*
| Results for one exam (admin + the staff who created it).
|   quiz  -> scores are automatic, this is just the report
|   paper -> open each student's uploaded sheets, enter marks + remarks, publish to the student
*/
function ExamResults() {
    const { id } = useParams();
    const base = getStoredUser()?.role === "admin" ? "/admin/exams" : "/staff/exams";
    const [data, setData] = useState(null);
    const [error, setError] = useState("");
    const [ok, setOk] = useState("");
    const [modal, setModal] = useState(null); // { row, marks, remarks, publish }
    const [saving, setSaving] = useState(false);

    const load = useCallback(
        () => examsApi.results(id).then(setData).catch((e) => setError(e.message)),
        [id]
    );
    useEffect(() => { load(); }, [load]);

    if (!data) return <div><PageHeader title="Results" /><Alert>{error}</Alert>{!error && <p>Loading...</p>}</div>;

    const { exam, rows } = data;
    const isPaper = exam.type === "paper";
    const total = Number(exam.total_marks);
    const done = rows.filter((r) => r.status !== "pending");
    const scored = rows.filter((r) => r.marks != null);
    const avg = scored.length ? (scored.reduce((s, r) => s + Number(r.marks), 0) / scored.length).toFixed(1) : "—";
    const top = scored.length ? Math.max(...scored.map((r) => Number(r.marks))) : "—";
    const toMark = rows.filter((r) => r.status === "submitted").length;
    const toPublish = rows.filter((r) => r.status === "graded").length;

    const openGrade = (row) =>
        setModal({ row, marks: row.marks ?? "", remarks: row.remarks || "", publish: true });

    const saveGrade = async (e) => {
        e.preventDefault();
        const m = Number(modal.marks);
        if (modal.marks === "" || Number.isNaN(m) || m < 0 || m > total) { setError(`Marks must be between 0 and ${total}`); return; }
        setSaving(true);
        setError("");
        try {
            await examsApi.grade(id, modal.row.attempt_id, { marks: m, remarks: modal.remarks, publish: modal.publish ? 1 : 0 });
            setOk(modal.publish ? `Result sent to ${modal.row.student_name}` : "Marks saved (not yet visible to the student)");
            setModal(null);
            load();
        } catch (err) {
            setError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const publishAll = async () => {
        if (!confirm(`Send results to ${toPublish} student(s)?`)) return;
        try { await examsApi.publish(id); setOk("Results published"); load(); } catch (err) { setError(err.message); }
    };

    const exportCsv = () => {
        const esc = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
        const lines = [["Student", "Batch", "Status", "Marks", "Total", "Remarks", "Submitted at"].map(esc).join(",")];
        rows.forEach((r) => lines.push([r.student_name, r.batch_name, r.status, r.marks ?? "", total, r.remarks || "", r.submitted_at || ""].map(esc).join(",")));
        const url = URL.createObjectURL(new Blob([lines.join("\n")], { type: "text/csv" }));
        const a = document.createElement("a");
        a.href = url; a.download = `${exam.title.replace(/\W+/g, "_")}_results.csv`; a.click();
        URL.revokeObjectURL(url);
    };

    return (
        <div>
            <PageHeader
                title={`${exam.title} — ${isPaper ? "Evaluation" : "Results"}`}
                action={<Link to={base} className="text-blue-700 hover:underline">← All exams</Link>}
            />
            <Alert>{error}</Alert>
            <Alert type="success">{ok}</Alert>

            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                <StatCard label="Students assigned" value={rows.length} />
                <StatCard label={isPaper ? "Sheets received" : "Attempted"} value={done.length} />
                <StatCard label="Average marks" value={avg} />
                <StatCard label="Highest" value={top} />
            </div>

            <div className="flex gap-3 mb-4 flex-wrap items-center">
                {isPaper && toMark > 0 && <span className="text-sm text-amber-700">{toMark} answer sheet(s) waiting to be marked</span>}
                {isPaper && toPublish > 0 && <Button onClick={publishAll}>Publish {toPublish} marked result(s)</Button>}
                <Button variant="ghost" onClick={exportCsv} className="ml-auto">Download CSV</Button>
            </div>

            {rows.length === 0 ? (
                <p className="text-gray-500 bg-white rounded-xl shadow p-4">No students in the selected batches yet.</p>
            ) : (
                <div className="bg-white rounded-xl shadow overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead className="bg-gray-50 text-gray-600">
                            <tr>
                                <th className="p-3">Student</th><th className="p-3">Batch</th><th className="p-3">Status</th>
                                <th className="p-3">Marks</th><th className="p-3">Submitted</th>
                                {isPaper && <th className="p-3 text-right">Action</th>}
                            </tr>
                        </thead>
                        <tbody>
                            {rows.map((r) => (
                                <tr key={r.student_id} className="border-t">
                                    <td className="p-3 font-medium">{r.student_name}</td>
                                    <td className="p-3">{r.batch_name}</td>
                                    <td className="p-3"><Badge>{r.status}</Badge></td>
                                    <td className="p-3">
                                        {r.marks != null ? `${r.marks} / ${total}` : "—"}
                                        {r.marks != null && exam.pass_marks != null && (
                                            <span className={`ml-2 text-xs font-semibold ${Number(r.marks) >= Number(exam.pass_marks) ? "text-green-700" : "text-red-600"}`}>
                                                {Number(r.marks) >= Number(exam.pass_marks) ? "PASS" : "FAIL"}
                                            </span>
                                        )}
                                    </td>
                                    <td className="p-3 whitespace-nowrap">{fmtDateTime(r.submitted_at)}</td>
                                    {isPaper && (
                                        <td className="p-3 text-right">
                                            {r.status !== "pending" && (
                                                <Button className="!py-1" variant={r.status === "submitted" ? "primary" : "ghost"} onClick={() => openGrade(r)}>
                                                    {r.status === "submitted" ? "Mark" : "View / edit"}
                                                </Button>
                                            )}
                                        </td>
                                    )}
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {modal && (
                <Modal title={`${modal.row.student_name} — answer sheets`} size="xl" onClose={() => setModal(null)}>
                    <Alert>{error}</Alert>
                    <p className="text-sm text-gray-500 mb-3">
                        {modal.row.files?.length || 0} page(s) · submitted {fmtDateTime(modal.row.submitted_at)}. Tap a page to open it full size.
                    </p>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 mb-5">
                        {(modal.row.files || []).map((f, i) => (
                            <a key={f.url} href={f.url} target="_blank" rel="noreferrer" className="border rounded-lg overflow-hidden bg-gray-50 block">
                                {isImage(f) ? (
                                    <img src={f.url} alt={`Page ${i + 1}`} className="w-full h-40 object-cover" loading="lazy" />
                                ) : (
                                    <div className="h-40 flex items-center justify-center text-gray-500 font-semibold">PDF</div>
                                )}
                                <p className="text-xs p-1.5 truncate">Page {i + 1}: {f.name}</p>
                            </a>
                        ))}
                    </div>

                    <form onSubmit={saveGrade}>
                        <div className="grid sm:grid-cols-[180px_1fr] gap-x-4">
                            <Field label={`Marks (out of ${total})`}>
                                <input type="number" min="0" max={total} step="0.5" className={inputCls} value={modal.marks}
                                    onChange={(e) => setModal({ ...modal, marks: e.target.value })} required />
                            </Field>
                            <Field label="Remarks for the student">
                                <textarea rows={2} className={inputCls} value={modal.remarks} onChange={(e) => setModal({ ...modal, remarks: e.target.value })} />
                            </Field>
                        </div>
                        <label className="flex items-center gap-2 text-sm mb-4">
                            <input type="checkbox" checked={modal.publish} onChange={(e) => setModal({ ...modal, publish: e.target.checked })} />
                            Send the result to the student now
                        </label>
                        <div className="flex gap-3">
                            <Button type="submit" disabled={saving}>{saving ? "Saving..." : "Save"}</Button>
                            <Button type="button" variant="ghost" onClick={() => setModal(null)}>Close</Button>
                        </div>
                    </form>
                </Modal>
            )}
        </div>
    );
}

export default ExamResults;