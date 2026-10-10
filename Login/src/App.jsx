import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";

import Login from "./pages/Login";
import Register from "./pages/Register";
import Profile from "./pages/Profile";
import Users from "./pages/admin/Users";
import AdminCourses from "./pages/admin/Courses";
import Batches from "./pages/admin/Batches";
import Purchases from "./pages/admin/Purchases";
import StudentCourses from "./pages/student/Courses";
import CourseDetail from "./pages/student/CourseDetail";
import MyCourses from "./pages/student/MyCourses";
import Assignments from "./pages/admin/Assignments";
import StaffDashboard from "./pages/staff/Dashboard";
import StaffAttendance from "./pages/staff/Attendance";
import StudentAttendance from "./pages/student/Attendance";
import LeaveInbox from "./pages/shared/LeaveInbox";
import MyLeaves from "./pages/shared/MyLeaves";
import ProtectedRoute from "./components/ProtectedRoute";
import Layout from "./components/Layout";
import Exams from "./pages/shared/Exams";
import ExamForm from "./pages/shared/ExamForm";
import ExamResults from "./pages/shared/ExamResults";
import StudentExams from "./pages/student/Exams";
import TakeExam from "./pages/student/TakeExam";
import PaperExam from "./pages/student/PaperExam";
import { getStoredUser, isLoggedIn, homePath } from "./utils/auth";

function Home() {
    if (!isLoggedIn()) return <Navigate to="/login" replace />;
    const u = getStoredUser();
    return <Navigate to={homePath(u?.role)} replace />;
}

const admin = ["admin"];
const student = ["student"];
const staff = ["staff"];

function App() {
    return (
        <BrowserRouter>
            <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/login" element={<Login />} />
                <Route path="/register" element={<Register />} />
                <Route path="/dashboard" element={<Home />} />

                <Route element={<ProtectedRoute><Layout /></ProtectedRoute>}>
                    <Route path="/profile" element={<Profile />} />

                    <Route path="/admin/users" element={<ProtectedRoute roles={admin}><Users /></ProtectedRoute>} />
                    <Route path="/admin/courses" element={<ProtectedRoute roles={admin}><AdminCourses /></ProtectedRoute>} />
                    <Route path="/admin/batches" element={<ProtectedRoute roles={admin}><Batches /></ProtectedRoute>} />

                    <Route path="/admin/purchases" element={<ProtectedRoute roles={admin}><Purchases /></ProtectedRoute>} />

                    <Route path="/admin/assignments" element={<ProtectedRoute roles={admin}><Assignments /></ProtectedRoute>} />
                    <Route path="/admin/leaves" element={<ProtectedRoute roles={admin}><LeaveInbox /></ProtectedRoute>} />

                    <Route path="/staff/dashboard" element={<ProtectedRoute roles={staff}><StaffDashboard /></ProtectedRoute>} />
                    <Route path="/staff/attendance" element={<ProtectedRoute roles={staff}><StaffAttendance /></ProtectedRoute>} />
                    <Route path="/staff/leaves" element={<ProtectedRoute roles={staff}><LeaveInbox /></ProtectedRoute>} />
                    <Route path="/staff/my-leave" element={<ProtectedRoute roles={staff}><MyLeaves /></ProtectedRoute>} />
                      
                                        {/* Exams: admin + staff create and evaluate */}
                    {[["/admin/exams", admin], ["/staff/exams", staff]].map(([base, roles]) => [
                        <Route key={base} path={base} element={<ProtectedRoute roles={roles}><Exams /></ProtectedRoute>} />,
                        <Route key={`${base}/new`} path={`${base}/new`} element={<ProtectedRoute roles={roles}><ExamForm /></ProtectedRoute>} />,
                        <Route key={`${base}/edit`} path={`${base}/:id/edit`} element={<ProtectedRoute roles={roles}><ExamForm /></ProtectedRoute>} />,
                        <Route key={`${base}/results`} path={`${base}/:id/results`} element={<ProtectedRoute roles={roles}><ExamResults /></ProtectedRoute>} />,
                    ])}

                    <Route path="/my-exams" element={<ProtectedRoute roles={student}><StudentExams /></ProtectedRoute>} />
                    <Route path="/my-exams/:id/take" element={<ProtectedRoute roles={student}><TakeExam /></ProtectedRoute>} />
                    <Route path="/my-exams/:id/paper" element={<ProtectedRoute roles={student}><PaperExam /></ProtectedRoute>} />

                    <Route path="/my-attendance" element={<ProtectedRoute roles={student}><StudentAttendance /></ProtectedRoute>} />
                    <Route path="/my-leaves" element={<ProtectedRoute roles={student}><MyLeaves /></ProtectedRoute>} />

                    <Route path="/courses" element={<ProtectedRoute roles={student}><StudentCourses /></ProtectedRoute>} />
                    <Route path="/courses/:id" element={<ProtectedRoute roles={student}><CourseDetail /></ProtectedRoute>} />
                    <Route path="/my-courses" element={<ProtectedRoute roles={student}><MyCourses /></ProtectedRoute>} />
                </Route>

                <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
        </BrowserRouter>
    );
}

export default App;
