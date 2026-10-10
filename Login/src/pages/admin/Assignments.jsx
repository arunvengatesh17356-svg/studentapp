import { useCallback, useEffect, useState } from "react";
import { assignmentsApi, batchesApi } from "../../services/api";
import { Alert, Button, Field, Modal, PageHeader, inputCls } from "../../components/ui";

const empty = { batch_id: "", subject_name: "", staff_id: "" };

/** Admin: decide which staff handles which subject in which batch. */
function Assignments() {
    const [rows, setRows] = useState([]);
    const [batches, setBatches] = useState([]);
    const [staff, setStaff] = useState([]);
    const [filter, setFilter] = useState({ batch_id: "", staff_id: "", search: "" });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [modal, setModal] = useState(null);
    const [formError, setFormError] = useState("");
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        batchesApi.list().then((d) => setBatches(d.batches)).catch((e) => setError(e.message));
        assignmentsApi.staff().then((d) => setStaff(d.staff)).catch((e) => setError(e.message));
    }, []);

    const load = useCallback(async () => {
        try {
            setError("");
            setRows((await assignmentsApi.list(filter)).assignments);
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    }, [filter]);

    useEffect(() => {
        const t = setTimeout(load, 250);
        return () => clearTimeout(t);
    }, [load]);

    const save = async (e) => {
        e.preventDefault();
        setFormError("");
        setSaving(true);
        try {
            const { id, ...payload } = modal;
            if (id) await assignmentsApi.update(id, payload);
            else await assignmentsApi.create(payload);
            setModal(null);
            load();
        } catch (err) {
            setFormError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const remove = async (r) => {
        if (!confirm(`Remove ${r.staff_name} from "${r.subject_name}" (${r.batch_name})?\nAttendance already marked for this subject will also be deleted.`)) return;
        try { await assignmentsApi.remove(r.id); load(); } catch (err) { setError(err.message); }
    };

    const openCreate = () => {
        if (batches.length === 0) return setError("Create a batch first.");
        if (staff.length === 0) return setError("There is no staff user yet. Go to Users and create a user with the Staff role.");
        setFormError("");
        setModal({ ...empty, batch_id: filter.batch_id || batches[0].id, staff_id: staff[0].id });
    };

    const set = (k) => (e) => setModal({ ...modal, [k]: e.target.value });
    const f = (k) => (e) => setFilter({ ...filter, [k]: e.target.value });

    return (
        <div>
            <PageHeader title="Staff & Subjects" action={<Button onClick={openCreate}>+ Assign Subject</Button>} />
            <p className="text-gray-600 text-sm mb-4">Choose which staff member teaches which subject in each batch. Staff then see only the students of their batches.</p>
            <Alert>{error}</Alert>

            <div className="flex gap-3 mb-4 flex-wrap">
                <input className={`${inputCls} max-w-xs`} placeholder="Search subject, staff or batch" value={filter.search} onChange={f("search")} />
                <select className={`${inputCls} max-w-[220px]`} value={filter.batch_id} onChange={f("batch_id")}>
                    <option value="">All batches</option>
                    {batches.map((b) => <option key={b.id} value={b.id}>{b.batch_name}</option>)}
                </select>
                <select className={`${inputCls} max-w-[200px]`} value={filter.staff_id} onChange={f("staff_id")}>
                    <option value="">All staff</option>
                    {staff.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
            </div>

            <div className="bg-white rounded-xl shadow overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead className="bg-gray-50 text-gray-600">
                        <tr><th className="p-3">Staff</th><th className="p-3">Subject</th><th className="p-3">Batch</th><th className="p-3">Course</th><th className="p-3">Students</th><th className="p-3 text-right">Actions</th></tr>
                    </thead>
                    <tbody>
                        {loading && <tr><td className="p-4" colSpan="6">Loading...</td></tr>}
                        {!loading && rows.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="6">No assignments yet</td></tr>}
                        {rows.map((r) => (
                            <tr key={r.id} className="border-t">
                                <td className="p-3 font-medium">{r.staff_name}<br /><span className="text-xs text-gray-500 font-normal">{r.staff_email}</span></td>
                                <td className="p-3">{r.subject_name}</td>
                                <td className="p-3">{r.batch_name}</td>
                                <td className="p-3">{r.course_name}</td>
                                <td className="p-3">{r.students}</td>
                                <td className="p-3 text-right whitespace-nowrap">
                                    <Button variant="ghost" className="mr-2 !py-1" onClick={() => { setFormError(""); setModal({ id: r.id, batch_id: r.batch_id, subject_name: r.subject_name, staff_id: r.staff_id }); }}>Edit</Button>
                                    <Button variant="danger" className="!py-1" onClick={() => remove(r)}>Remove</Button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {modal && (
                <Modal title={modal.id ? "Edit Assignment" : "Assign Subject"} onClose={() => setModal(null)}>
                    <Alert>{formError}</Alert>
                    <form onSubmit={save}>
                        <Field label="Batch">
                            <select className={inputCls} value={modal.batch_id} onChange={set("batch_id")} required>
                                {batches.map((b) => <option key={b.id} value={b.id}>{b.batch_name} — {b.course_name}</option>)}
                            </select>
                        </Field>
                        <Field label="Subject">
                            <input className={inputCls} value={modal.subject_name} onChange={set("subject_name")} placeholder="e.g. History, Polity, Geography" required />
                        </Field>
                        <Field label="Staff (teacher)">
                            <select className={inputCls} value={modal.staff_id} onChange={set("staff_id")} required>
                                {staff.map((s) => <option key={s.id} value={s.id}>{s.name} ({s.email})</option>)}
                            </select>
                        </Field>
                        <div className="flex justify-end gap-2 mt-4">
                            <Button type="button" variant="ghost" onClick={() => setModal(null)}>Cancel</Button>
                            <Button disabled={saving}>{saving ? "Saving..." : "Save"}</Button>
                        </div>
                    </form>
                </Modal>
            )}
        </div>
    );
}

export default Assignments;
