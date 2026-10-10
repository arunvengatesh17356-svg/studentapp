import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { staffApi } from "../../services/api";
import { getStoredUser } from "../../utils/auth";
import { Alert, Badge, Button, Modal, PageHeader, StatCard, formatDate } from "../../components/ui";

/** Staff home: my subjects/batches, and the students who joined those batches. */
function StaffDashboard() {
    const me = getStoredUser();
    const [data, setData] = useState(null);
    const [error, setError] = useState("");
    const [view, setView] = useState(null); // { assignment, students }

    useEffect(() => {
        staffApi.dashboard().then(setData).catch((e) => setError(e.message));
    }, []);

    const showStudents = async (a) => {
        try {
            const d = await staffApi.students(a.id);
            setView({ assignment: a, students: d.students });
        } catch (e) {
            setError(e.message);
        }
    };

    if (!data) return <div><PageHeader title="Dashboard" /><Alert>{error}</Alert>{!error && <p>Loading...</p>}</div>;

    const { assignments, summary } = data;

    return (
        <div>
            <PageHeader title={`Welcome, ${me?.name}`} />
            <Alert>{error}</Alert>

            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                <StatCard label="My batches" value={summary.batches} />
                <StatCard label="My subjects" value={summary.subjects} />
                <StatCard label="Students" value={summary.students} />
                <StatCard label="Pending leaves" value={summary.pending_leaves} />
            </div>

            <h2 className="font-semibold text-lg text-blue-900 mb-2">My subjects & batches</h2>
            {assignments.length === 0 ? (
                <p className="text-gray-500 bg-white rounded-xl shadow p-4">
                    No subject has been assigned to you yet. Please ask the admin to assign a subject and batch.
                </p>
            ) : (
                <div className="bg-white rounded-xl shadow overflow-x-auto">
                    <table className="w-full text-left text-sm">
                        <thead className="bg-gray-50 text-gray-600">
                            <tr><th className="p-3">Subject</th><th className="p-3">Batch</th><th className="p-3">Course</th><th className="p-3">Dates</th><th className="p-3">Students</th><th className="p-3 text-right">Actions</th></tr>
                        </thead>
                        <tbody>
                            {assignments.map((a) => (
                                <tr key={a.id} className="border-t">
                                    <td className="p-3 font-medium">{a.subject_name}</td>
                                    <td className="p-3">{a.batch_name} <Badge>{a.batch_status}</Badge></td>
                                    <td className="p-3">{a.course_name}</td>
                                    <td className="p-3 whitespace-nowrap">{formatDate(a.start_date)} → {formatDate(a.end_date)}</td>
                                    <td className="p-3">{a.students}</td>
                                    <td className="p-3 text-right whitespace-nowrap">
                                        <Button variant="ghost" className="mr-2 !py-1" onClick={() => showStudents(a)}>Students</Button>
                                        <Link to={`/staff/attendance?a=${a.id}`} className="inline-block bg-blue-900 text-white px-4 py-1 rounded-lg font-semibold hover:bg-blue-800">Attendance</Link>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}

            {view && (
                <Modal title={`${view.assignment.batch_name} — ${view.assignment.subject_name}`} onClose={() => setView(null)}>
                    {view.students.length === 0 ? (
                        <p className="text-gray-500">No student has joined this batch yet.</p>
                    ) : (
                        <ul className="divide-y">
                            {view.students.map((s, i) => (
                                <li key={s.id} className="py-2 flex gap-3">
                                    <span className="text-gray-400 w-6">{i + 1}</span>
                                    <span><b>{s.name}</b><br /><span className="text-sm text-gray-500">{s.email}</span></span>
                                </li>
                            ))}
                        </ul>
                    )}
                    <div className="flex justify-end mt-4"><Button variant="ghost" onClick={() => setView(null)}>Close</Button></div>
                </Modal>
            )}
        </div>
    );
}

export default StaffDashboard;
