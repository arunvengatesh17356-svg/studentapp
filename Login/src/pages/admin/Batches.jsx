import { Link } from "react-router-dom";
import { useCallback, useEffect, useState } from "react";
import { batchesApi, coursesApi } from "../../services/api";
import { Alert, Badge, Button, Field, Modal, PageHeader, formatDate, inputCls } from "../../components/ui";

const empty = { batch_name: "", course_id: "", start_date: "", end_date: "", capacity: 30, status: "Active" };

function Batches() {
    const [batches, setBatches] = useState([]);
    const [courses, setCourses] = useState([]);
    const [filter, setFilter] = useState({ course_id: "", status: "", search: "" });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [modal, setModal] = useState(null);
    const [formError, setFormError] = useState("");
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        coursesApi.list().then((d) => setCourses(d.courses)).catch((e) => setError(e.message));
    }, []);

    const load = useCallback(async () => {
        try {
            setBatches((await batchesApi.list(filter)).batches);
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
            if (id) await batchesApi.update(id, payload);
            else await batchesApi.create(payload);
            setModal(null);
            load();
        } catch (err) {
            setFormError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const remove = async (b) => {
        if (!confirm(`Delete batch "${b.batch_name}"?`)) return;
        try { await batchesApi.remove(b.id); load(); } catch (err) { setError(err.message); }
    };

    const set = (k) => (e) => setModal({ ...modal, [k]: e.target.value });
    const f = (k) => (e) => setFilter({ ...filter, [k]: e.target.value });

    return (
        <div>
            <PageHeader
                title="Batches"
                action={
                    <Button
                        onClick={() => {
                            if (courses.length === 0) return setError("Create a course first, then add batches to it.");
                            setFormError("");
                            setModal({ ...empty, course_id: courses[0].id });
                        }}
                    >
                        + Create Batch
                    </Button>
                }
            />
            <Alert>{error}</Alert>

            <div className="flex gap-3 mb-4 flex-wrap">
                <input className={`${inputCls} max-w-xs`} placeholder="Search batch name" value={filter.search} onChange={f("search")} />
                <select className={`${inputCls} max-w-[220px]`} value={filter.course_id} onChange={f("course_id")}>
                    <option value="">All courses</option>
                    {courses.map((c) => <option key={c.id} value={c.id}>{c.course_name}</option>)}
                </select>
                <select className={`${inputCls} max-w-[160px]`} value={filter.status} onChange={f("status")}>
                    <option value="">All statuses</option>
                    <option>Active</option><option>Inactive</option><option>Completed</option>
                </select>
            </div>

            <div className="bg-white rounded-xl shadow overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead className="bg-gray-50 text-gray-600">
                        <tr><th className="p-3">Batch</th><th className="p-3">Course</th><th className="p-3">Dates</th><th className="p-3">Subjects / Staff</th><th className="p-3">Seats</th><th className="p-3">Status</th><th className="p-3 text-right">Actions</th></tr>
                    </thead>
                    <tbody>
                        {loading && <tr><td className="p-4" colSpan="7">Loading...</td></tr>}
                        {!loading && batches.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="7">No batches found</td></tr>}
                        {batches.map((b) => (
                            <tr key={b.id} className="border-t">
                                <td className="p-3 font-medium">{b.batch_name}</td>
                                <td className="p-3">{b.course_name}</td>
                                <td className="p-3 whitespace-nowrap">{formatDate(b.start_date)} → {formatDate(b.end_date)}</td>
                                <td className="p-3 text-xs">
                                    {b.subjects?.length ? b.subjects.map((x) => <div key={x}>{x}</div>) : <Link to="/admin/assignments" className="text-blue-700">+ Assign</Link>}
                                </td>
                                <td className="p-3">{b.enrolled} / {b.capacity}</td>
                                <td className="p-3"><Badge>{b.status}</Badge></td>
                                <td className="p-3 text-right whitespace-nowrap">
                                    <Button variant="ghost" className="mr-2 !py-1" onClick={() => { setFormError(""); setModal({ ...b, start_date: b.start_date || "", end_date: b.end_date || "" }); }}>Edit</Button>
                                    <Button variant="danger" className="!py-1" onClick={() => remove(b)}>Delete</Button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {modal && (
                <Modal title={modal.id ? "Edit Batch" : "Create Batch"} onClose={() => setModal(null)}>
                    <Alert>{formError}</Alert>
                    <form onSubmit={save}>
                        <Field label="Batch name"><input className={inputCls} value={modal.batch_name} onChange={set("batch_name")} required /></Field>
                        <Field label="Course">
                            <select className={inputCls} value={modal.course_id} onChange={set("course_id")} required>
                                {courses.map((c) => <option key={c.id} value={c.id}>{c.course_name}</option>)}
                            </select>
                        </Field>
                        <div className="grid grid-cols-2 gap-3">
                            <Field label="Start date"><input type="date" className={inputCls} value={modal.start_date} onChange={set("start_date")} /></Field>
                            <Field label="End date"><input type="date" className={inputCls} value={modal.end_date} min={modal.start_date || undefined} onChange={set("end_date")} /></Field>
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                            <Field label="Capacity"><input type="number" min="1" className={inputCls} value={modal.capacity} onChange={set("capacity")} required /></Field>
                            <Field label="Status">
                                <select className={inputCls} value={modal.status} onChange={set("status")}>
                                    <option>Active</option><option>Inactive</option><option>Completed</option>
                                </select>
                            </Field>
                        </div>
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

export default Batches;
