import { useEffect, useState } from "react";
import { leavesApi, studentApi } from "../../services/api";
import { getStoredUser } from "../../utils/auth";
import { Alert, Badge, Button, Field, PageHeader, formatDate, inputCls, todayStr } from "../../components/ui";

/*
| Apply for leave.
|   student -> choose batch; goes to that batch's staff and the admin
|   staff   -> goes to the admin
*/
function MyLeaves() {
    const isStudent = getStoredUser()?.role === "student";
    const [leaves, setLeaves] = useState([]);
    const [batches, setBatches] = useState([]);
    const [form, setForm] = useState({ batch_id: "", from_date: todayStr(), to_date: todayStr(), reason: "" });
    const [error, setError] = useState("");
    const [ok, setOk] = useState("");
    const [saving, setSaving] = useState(false);
    const [loading, setLoading] = useState(true);

    const load = () => leavesApi.mine().then((d) => setLeaves(d.leaves)).catch((e) => setError(e.message)).finally(() => setLoading(false));

    useEffect(() => {
        load();
        if (isStudent) {
            studentApi.batches().then((d) => {
                setBatches(d.batches);
                if (d.batches.length) setForm((f) => ({ ...f, batch_id: d.batches[0].id }));
            }).catch((e) => setError(e.message));
        }
    }, [isStudent]);

    const set = (k) => (e) => {
        const v = e.target.value;
        setForm((f) => ({ ...f, [k]: v, ...(k === "from_date" && f.to_date < v ? { to_date: v } : {}) }));
    };

    const submit = async (e) => {
        e.preventDefault();
        setError(""); setOk("");
        setSaving(true);
        try {
            const r = await leavesApi.create(form);
            setOk(r.message);
            setForm({ ...form, reason: "" });
            load();
        } catch (err) {
            setError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const cancel = async (l) => {
        if (!confirm("Cancel this leave request?")) return;
        try { await leavesApi.cancel(l.id); load(); } catch (err) { setError(err.message); }
    };

    const blocked = isStudent && batches.length === 0;

    return (
        <div className="max-w-4xl">
            <PageHeader title={isStudent ? "Leave" : "My Leave"} />
            <Alert>{error}</Alert>
            <Alert type="success">{ok}</Alert>

            <div className="bg-white rounded-xl shadow p-5 mb-6">
                <h2 className="font-semibold text-blue-900 mb-1">Apply for leave</h2>
                <p className="text-sm text-gray-500 mb-4">
                    {isStudent ? "Your request goes to the staff handling your batch and to the admin." : "Your request goes to the admin."}
                </p>
                {blocked ? (
                    <p className="text-gray-500">You can apply for leave after you buy a course and join a batch (payment must be completed). Buy one from Courses.</p>
                ) : (
                    <form onSubmit={submit}>
                        {isStudent && (
                            <Field label="Batch">
                                <select className={inputCls} value={form.batch_id} onChange={set("batch_id")} required>
                                    {batches.map((b) => <option key={b.id} value={b.id}>{b.batch_name} — {b.course_name}</option>)}
                                </select>
                            </Field>
                        )}
                        {isStudent && (() => {
                            const b = batches.find((x) => String(x.id) === String(form.batch_id));
                            if (!b) return null;
                            return b.staff?.length ? (
                                <p className="text-sm bg-blue-50 text-blue-900 rounded-lg p-3 mb-3">
                                    Will be sent to: {b.staff.map((s) => `${s.name} (${s.subject_name})`).join(", ")} and the admin.
                                </p>
                            ) : (
                                <p className="text-sm bg-amber-50 text-amber-800 rounded-lg p-3 mb-3">
                                    No staff is assigned to this batch yet, so this request will go to the admin only.
                                </p>
                            );
                        })()}
                        <div className="grid grid-cols-2 gap-3">
                            <Field label="From"><input type="date" className={inputCls} value={form.from_date} onChange={set("from_date")} required /></Field>
                            <Field label="To"><input type="date" className={inputCls} value={form.to_date} min={form.from_date} onChange={set("to_date")} required /></Field>
                        </div>
                        <Field label="Reason">
                            <textarea className={inputCls} rows="3" maxLength={1000} value={form.reason} onChange={set("reason")} required />
                        </Field>
                        <Button disabled={saving}>{saving ? "Sending..." : "Send request"}</Button>
                    </form>
                )}
            </div>

            <h2 className="font-semibold text-blue-900 mb-2">My requests</h2>
            <div className="bg-white rounded-xl shadow overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead className="bg-gray-50 text-gray-600">
                        <tr>{isStudent && <th className="p-3">Batch</th>}<th className="p-3">Dates</th><th className="p-3">Reason</th><th className="p-3">Status</th><th className="p-3" /></tr>
                    </thead>
                    <tbody>
                        {loading && <tr><td className="p-4" colSpan="5">Loading...</td></tr>}
                        {!loading && leaves.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="5">No leave requests yet</td></tr>}
                        {leaves.map((l) => (
                            <tr key={l.id} className="border-t align-top">
                                {isStudent && <td className="p-3">{l.batch_name}</td>}
                                <td className="p-3 whitespace-nowrap">{formatDate(l.from_date)}{l.to_date !== l.from_date && <> → {formatDate(l.to_date)}</>}</td>
                                <td className="p-3 max-w-xs whitespace-pre-line">{l.reason}</td>
                                <td className="p-3">
                                    <Badge>{l.status}</Badge>
                                    {l.reviewed_by_name && <p className="text-xs text-gray-500 mt-1">by {l.reviewed_by_name}</p>}
                                    {l.review_note && <p className="text-xs text-gray-500">“{l.review_note}”</p>}
                                </td>
                                <td className="p-3 text-right">
                                    {l.status === "pending" && <Button variant="ghost" className="!py-1" onClick={() => cancel(l)}>Cancel</Button>}
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

export default MyLeaves;
