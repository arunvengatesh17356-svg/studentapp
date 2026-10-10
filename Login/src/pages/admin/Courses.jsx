import { useCallback, useEffect, useState } from "react";
import { coursesApi } from "../../services/api";
import { Alert, Badge, Button, Field, Modal, PageHeader, formatPrice, inputCls } from "../../components/ui";

const empty = { course_name: "", description: "", price: 0, duration: "", image_url: "", status: "draft" };

function Courses() {
    const [courses, setCourses] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [modal, setModal] = useState(null);
    const [formError, setFormError] = useState("");
    const [saving, setSaving] = useState(false);

    const load = useCallback(async () => {
        try {
            setCourses((await coursesApi.list()).courses);
        } catch (e) {
            setError(e.message);
        } finally {
            setLoading(false);
        }
    }, []);
    useEffect(() => { load(); }, [load]);

    const save = async (e) => {
        e.preventDefault();
        setFormError("");
        setSaving(true);
        try {
            const { id, ...payload } = modal;
            if (id) await coursesApi.update(id, payload);
            else await coursesApi.create(payload);
            setModal(null);
            load();
        } catch (err) {
            setFormError(err.message);
        } finally {
            setSaving(false);
        }
    };

    const remove = async (c) => {
        if (!confirm(`Delete "${c.course_name}" and its batches?`)) return;
        try { await coursesApi.remove(c.id); load(); } catch (err) { setError(err.message); }
    };

    const set = (k) => (e) => setModal({ ...modal, [k]: e.target.value });

    return (
        <div>
            <PageHeader title="Courses" action={<Button onClick={() => { setFormError(""); setModal({ ...empty }); }}>+ Create Course</Button>} />
            <Alert>{error}</Alert>
            <div className="bg-white rounded-xl shadow overflow-x-auto">
                <table className="w-full text-left text-sm">
                    <thead className="bg-gray-50 text-gray-600">
                        <tr><th className="p-3">Course</th><th className="p-3">Price</th><th className="p-3">Duration</th><th className="p-3">Active batches</th><th className="p-3">Status</th><th className="p-3 text-right">Actions</th></tr>
                    </thead>
                    <tbody>
                        {loading && <tr><td className="p-4" colSpan="6">Loading...</td></tr>}
                        {!loading && courses.length === 0 && <tr><td className="p-4 text-gray-500" colSpan="6">No courses yet. Create one so you can add batches.</td></tr>}
                        {courses.map((c) => (
                            <tr key={c.id} className="border-t">
                                <td className="p-3 font-medium">{c.course_name}</td>
                                <td className="p-3">{formatPrice(c.price)}</td>
                                <td className="p-3">{c.duration || "—"}</td>
                                <td className="p-3">{c.active_batches}</td>
                                <td className="p-3"><Badge>{c.status}</Badge></td>
                                <td className="p-3 text-right whitespace-nowrap">
                                    <Button variant="ghost" className="mr-2 !py-1" onClick={() => { setFormError(""); setModal({ ...c, description: c.description || "", duration: c.duration || "", image_url: c.image_url || "" }); }}>Edit</Button>
                                    <Button variant="danger" className="!py-1" onClick={() => remove(c)}>Delete</Button>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {modal && (
                <Modal title={modal.id ? "Edit Course" : "Create Course"} onClose={() => setModal(null)}>
                    <Alert>{formError}</Alert>
                    <form onSubmit={save}>
                        <Field label="Course name"><input className={inputCls} value={modal.course_name} onChange={set("course_name")} required /></Field>
                        <Field label="Description"><textarea rows="3" className={inputCls} value={modal.description} onChange={set("description")} /></Field>
                        <div className="grid grid-cols-2 gap-3">
                            <Field label="Price (₹)"><input type="number" min="0" step="0.01" className={inputCls} value={modal.price} onChange={set("price")} required /></Field>
                            <Field label="Duration"><input className={inputCls} placeholder="e.g. 6 months" value={modal.duration} onChange={set("duration")} /></Field>
                        </div>
                        <Field label="Image URL"><input className={inputCls} value={modal.image_url} onChange={set("image_url")} /></Field>
                        <Field label="Status">
                            <select className={inputCls} value={modal.status} onChange={set("status")}>
                                <option value="draft">Draft (hidden)</option>
                                <option value="published">Published (students can buy)</option>
                                <option value="inactive">Inactive</option>
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

export default Courses;
